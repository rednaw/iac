#!/usr/bin/env bash
# Binary smoke: tunnel up? renew? (Mac)
#   task vpn:smoke
#
# Intended test for burn: hotel Wi‑Fi + OneXray ON + Custom Routing.
# eSIM path can reach a hotel-burned IP — OK here ≠ OK at the hotel.
#
# Exit 0 only for VERDICT=OK (tunnel via this VPS).
# Optional: VPN_DEST=…  EXPECT_IP=…  TIMEOUT=…  FAST=…
set -euo pipefail

VPN_DEST="${VPN_DEST:-amateurkunstamstelveen.nl}"
EXPECT_IP="${EXPECT_IP:-}"
TIMEOUT="${TIMEOUT:-5}"
FAST="${FAST:-3}"

ok() { printf '  ✓  %s\n' "$1"; }
fail() { printf '  ✗  %s\n' "$1"; }
skip() { printf '  –  %s\n' "$1"; }

# Hard cap so DNS / stuck sockets cannot hang (Wi‑Fi off).
run_to() {
  local secs=$1
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 1 "$secs" "$@"
  else
    "$@"
  fi
}

curl_ok() {
  local url=$1; shift
  run_to "$TIMEOUT" curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$@" -o /dev/null "$url" 2>/dev/null
}

http_code() {
  local url=$1 code
  shift
  code=$(run_to "$TIMEOUT" curl -4 -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
    -o /dev/null -w '%{http_code}' "$@" "$url" 2>/dev/null) || true
  if [[ "$code" =~ ^[0-9]{3}$ ]]; then
    echo "$code"
  else
    echo "000"
  fi
}

# First IPv4 in a free-form line (ipip.net, etc.).
first_ipv4() {
  echo "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# Fail fast when the interface is down — literal IPs, no DNS, before hcloud.
# (hcloud / getaddrinfo can hang a long time with Wi‑Fi off.)
if ! run_to "$FAST" curl -4 -sS --connect-timeout "$FAST" --max-time "$FAST" \
     -o /dev/null "http://1.1.1.1/" 2>/dev/null \
  && ! run_to "$FAST" curl -4 -sS --connect-timeout "$FAST" --max-time "$FAST" \
     -o /dev/null "http://223.5.5.5/" 2>/dev/null; then
  echo "VPN quick check"
  echo ""
  echo "Result: No network — Wi‑Fi or mobile data looks down. Turn a network on, then run again."
  exit 1
fi

if [ -z "$EXPECT_IP" ]; then
  EXPECT_IP=$(run_to 8 task hostkeys:ip -- vpn 2>/dev/null || true)
fi

echo "VPN quick check"
echo "  Are you exiting through the travel VPS? (OneXray on + this network)"
if [ -n "$EXPECT_IP" ]; then
  echo "  Expected VPS address: ${EXPECT_IP}"
fi
echo "  Cover site (dest):    ${VPN_DEST}"
echo ""
echo "Checks:"

IPIFY=""
DIRECT_IP=""
CN_LINE=""
CN_OK=0
WEST_OK=0
VPS443_OK=0
IPIFY_OK=0
MATCH_OK=0
SPLIT_OK=0
DIRECT_SAME=0
ESIMISH=0

# api.ipify.org — public address (often blocked without the tunnel).
# Do not use Cloudflare — it frequently loads on mainland Wi‑Fi without OneXray.
if IPIFY=$(curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" https://api.ipify.org 2>/dev/null) \
  && [[ "$IPIFY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IPIFY_OK=1
  ok "Western egress address: ${IPIFY}"
else
  fail "No Western egress address (api.ipify.org) — usual when OneXray is OFF here"
  IPIFY=""
fi

if [ -n "$EXPECT_IP" ] && [ "$IPIFY_OK" -eq 1 ]; then
  if [ "$IPIFY" = "$EXPECT_IP" ]; then
    MATCH_OK=1
    ok "That address is our VPS — OneXray tunnel is ON"
  else
    fail "Western address ${IPIFY} is not our VPS (${EXPECT_IP}) — wrong link, old config, or tunnel off"
  fi
elif [ -z "$EXPECT_IP" ]; then
  skip "Could not look up VPS address (skipping “is it our server?” check)"
fi

if CN_LINE=$(curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" https://myip.ipip.net 2>/dev/null); then
  CN_OK=1
  DIRECT_IP=$(first_ipv4 "$CN_LINE")
  ok "Direct/China path works — ${CN_LINE}"
  # Trip.com / CMCC breakout often labels as 新加坡, not 中国.
  if echo "$CN_LINE" | grep -qE '新加坡|Hong Kong|香港|Korea|日本|美国|台湾'; then
    ESIMISH=1
  fi
else
  fail "Direct/China path failed — local network or captive portal?"
fi

if [ "$IPIFY_OK" -eq 1 ] && [ -n "$DIRECT_IP" ]; then
  if [ "$IPIFY" = "$DIRECT_IP" ]; then
    DIRECT_SAME=1
    fail "Western and direct show the same address (${IPIFY}) — OneXray looks OFF (or routing not split)"
  else
    SPLIT_OK=1
    ok "Split routing looks right — China/direct ${DIRECT_IP} vs Western ${IPIFY}"
  fi
fi

# Direct reachability of VPS:443 is a burn probe. With the tunnel ON, this path
# often hairpins or times out even when the VPS is fine — skip it then.
PROBE_IP="${EXPECT_IP:-$IPIFY}"
if [ "$MATCH_OK" -eq 1 ]; then
  VPS443_OK=1
elif [ -n "$PROBE_IP" ]; then
  code=$(http_code "https://${VPN_DEST}/" --resolve "${VPN_DEST}:443:${PROBE_IP}")
  if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
    VPS443_OK=1
    ok "VPS port 443 answers from this network (HTTP ${code})"
  else
    fail "VPS port 443 not reachable from here (HTTP ${code}) — burned Wi‑Fi or box down?"
  fi
else
  fail "No address to probe for VPS port 443"
fi

# Normally needs the tunnel from mainland (Cloudflare does not count).
if curl_ok "https://www.wikipedia.org/"; then
  WEST_OK=1
  ok "Wikipedia loads — tunnel/breakout likely on"
else
  fail "Wikipedia failed — usual when OneXray is OFF here"
fi

if curl_ok "https://www.baidu.com/"; then
  CN_OK=1
  ok "Local/China web works (Baidu)"
else
  CN_OK=0
  fail "Local/China web failed (Baidu)"
fi

echo ""

# --- mode / path ---
# OneXray OFF on mainland Wi‑Fi often blocks ipify entirely (not “same IP both ways”).
# That is tunnel-off, not a burned VPS — especially when VPS:443 still answers directly.
mode="unknown"
if [ "$MATCH_OK" -eq 1 ]; then
  mode="tunnel"
elif [ "$DIRECT_SAME" -eq 1 ]; then
  mode="direct"
elif [ "$IPIFY_OK" -eq 0 ] && [ "$CN_OK" -eq 1 ] && [ "$MATCH_OK" -eq 0 ]; then
  mode="direct"
elif [ "$IPIFY_OK" -eq 1 ] && [ -n "$EXPECT_IP" ]; then
  mode="other-egress"
fi

path="unknown"
if [ "$ESIMISH" -eq 1 ]; then
  path="esim-ish"
elif [ "$CN_OK" -eq 1 ]; then
  path="direct-cn-or-hotel"
fi

case "$mode" in
  tunnel) mode_human="Tunnel ON (traffic exits via our VPS)" ;;
  direct) mode_human="Tunnel OFF (not exiting via our VPS)" ;;
  other-egress) mode_human="Online, but not via our VPS" ;;
  *) mode_human="Unclear" ;;
esac

case "$path" in
  esim-ish) path_human="Looks like travel eSIM / overseas breakout (not plain mainland hotel Wi‑Fi)" ;;
  direct-cn-or-hotel) path_human="Looks like mainland China or hotel Wi‑Fi (direct path)" ;;
  *) path_human="Could not tell which local path you’re on" ;;
esac

echo "Summary"
echo "  Mode: ${mode_human}"
echo "  Path: ${path_human}"

# --- verdict ---
verdict="DOWN"
hint="Network looks dead. Fix Wi‑Fi / mobile data first, then run again."

# MATCH_OK already proves egress via this VPS; vps443 is extra (can flake in some nets).
if [ "$MATCH_OK" -eq 1 ] && [ "$WEST_OK" -eq 1 ]; then
  verdict="OK"
  if [ "$ESIMISH" -eq 1 ]; then
    hint="Tunnel works on eSIM/breakout. That does NOT prove hotel Wi‑Fi is fine — retest on hotel Wi‑Fi with OneXray ON."
  elif [ "$SPLIT_OK" -eq 0 ]; then
    hint="Tunnel works. If China apps should bypass the VPN, check Custom Routing / GeoData in OneXray."
  else
    hint="All good on this network — no IP renew needed from here."
  fi
elif [ "$mode" = "direct" ]; then
  verdict="OFF"
  if [ "$VPS443_OK" -eq 1 ]; then
    hint="Turn OneXray ON, then run again. (VPS still reachable directly — this is not a burned-IP signal by itself.)"
  else
    hint="Turn OneXray ON, then run again. If it still cannot reach the VPS on hotel Wi‑Fi, then consider renewing the IP."
  fi
elif [ "$mode" = "other-egress" ] || { [ "$WEST_OK" -eq 1 ] && [ "$MATCH_OK" -eq 0 ]; }; then
  verdict="ROUTING"
  hint="Western sites work, but not through this VPS. Re-import the latest share link in OneXray, or turn the tunnel on. Not automatically a “renew IP” problem."
elif [ "$CN_OK" -eq 1 ] && [ "$VPS443_OK" -eq 0 ]; then
  verdict="BURNED?"
  hint="Local net OK; VPS unreachable. On hotel Wi‑Fi with OneXray ON (not only eSIM): confirm the box is up, then renew the VPS IP (see trip manual §6.1)."
elif [ "$CN_OK" -eq 0 ] && [ "$IPIFY_OK" -eq 0 ] && [ "$WEST_OK" -eq 0 ]; then
  verdict="DOWN"
  hint="Nothing works. Check captive portal, Wi‑Fi login, or mobile signal first."
else
  verdict="TUNNEL"
  hint="Mixed results. Turn OneXray ON on hotel Wi‑Fi, then run again."
fi

echo ""
case "$verdict" in
  OK) echo "Result: OK — ${hint}" ;;
  OFF) echo "Result: Tunnel off — ${hint}" ;;
  ROUTING) echo "Result: Wrong exit — ${hint}" ;;
  BURNED?) echo "Result: Possible burned IP — ${hint}" ;;
  DOWN) echo "Result: No network — ${hint}" ;;
  *) echo "Result: Need another look — ${hint}" ;;
esac

if [ "$verdict" = "OK" ]; then
  exit 0
fi
exit 1
