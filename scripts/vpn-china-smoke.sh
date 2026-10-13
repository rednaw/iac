#!/usr/bin/env bash
# Binary smoke: tunnel up? renew? (Mac)
#   task vpn:smoke
#
# Intended test for burn: hotel Wi‑Fi + OneXray ON + Custom Routing.
# eSIM path can reach a hotel-burned IP — OK here ≠ OK at the hotel.
#
# Exit 0 only for VERDICT=OK (tunnel via this VPS).
# Optional: VPN_DEST=…  EXPECT_IP=…  TIMEOUT=…
set -euo pipefail

VPN_DEST="${VPN_DEST:-amateurkunstamstelveen.nl}"
EXPECT_IP="${EXPECT_IP:-}"
TIMEOUT="${TIMEOUT:-12}"

ok() { printf '  %-12s OK   %s\n' "$1" "${2:-}"; }
fail() { printf '  %-12s FAIL %s\n' "$1" "${2:-}"; }

curl_ok() {
  local url=$1; shift
  curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$@" -o /dev/null "$url" 2>/dev/null
}

http_code() {
  local url=$1; shift
  curl -4 -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
    -o /dev/null -w '%{http_code}' "$@" "$url" 2>/dev/null || echo "000"
}

# First IPv4 in a free-form line (ipip.net, etc.).
first_ipv4() {
  echo "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

if [ -z "$EXPECT_IP" ]; then
  EXPECT_IP=$(task hostkeys:ip -- vpn 2>/dev/null || true)
fi

echo "smoke (dest=${VPN_DEST}${EXPECT_IP:+; expect=${EXPECT_IP}})"
echo ""

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

if IPIFY=$(curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" https://api.ipify.org 2>/dev/null) \
  && [[ "$IPIFY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IPIFY_OK=1
  ok "ipify" "$IPIFY  (Western egress)"
else
  fail "ipify" "no Western egress"
  IPIFY=""
fi

if [ -n "$EXPECT_IP" ] && [ "$IPIFY_OK" -eq 1 ]; then
  if [ "$IPIFY" = "$EXPECT_IP" ]; then
    MATCH_OK=1
    ok "match" "ipify = VPS → tunnel is ON (OneXray or other)"
  else
    fail "match" "ipify ${IPIFY} ≠ VPS ${EXPECT_IP} → not exiting via this VPS"
  fi
elif [ -z "$EXPECT_IP" ]; then
  echo "  match        SKIP (no EXPECT_IP / hcloud)"
fi

if CN_LINE=$(curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" https://myip.ipip.net 2>/dev/null); then
  CN_OK=1
  DIRECT_IP=$(first_ipv4 "$CN_LINE")
  ok "ipip" "$CN_LINE"
  # Trip.com / CMCC breakout often labels as 新加坡, not 中国.
  if echo "$CN_LINE" | grep -qE '新加坡|Hong Kong|香港|Korea|日本|美国|台湾'; then
    ESIMISH=1
  fi
else
  fail "ipip" "direct/geo fetch failed"
fi

if [ "$IPIFY_OK" -eq 1 ] && [ -n "$DIRECT_IP" ]; then
  if [ "$IPIFY" = "$DIRECT_IP" ]; then
    DIRECT_SAME=1
    fail "split" "same IP both ways → OneXray OFF (or no split), using ${IPIFY}"
  else
    SPLIT_OK=1
    ok "split" "direct ${DIRECT_IP} ≠ western ${IPIFY}"
  fi
fi

PROBE_IP="${EXPECT_IP:-$IPIFY}"
if [ -n "$PROBE_IP" ]; then
  code=$(http_code "https://${VPN_DEST}/" --resolve "${VPN_DEST}:443:${PROBE_IP}")
  if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
    VPS443_OK=1
    ok "vps443" "HTTP ${code} to ${PROBE_IP} (from *this* network path)"
  else
    fail "vps443" "HTTP ${code} — VPS:443 unreachable from here"
  fi
else
  fail "vps443" "no IP to probe"
fi

if curl_ok "https://www.cloudflare.com/cdn-cgi/trace"; then
  WEST_OK=1
  ok "western" "cloudflare reachable"
else
  fail "western" "cloudflare failed"
fi

if curl_ok "https://www.baidu.com/"; then
  CN_OK=1
  ok "baidu" "baidu reachable"
else
  CN_OK=0
  fail "baidu" "baidu failed"
fi

echo ""

# --- mode / path ---
mode="unknown"
if [ "$MATCH_OK" -eq 1 ]; then
  mode="tunnel"
elif [ "$DIRECT_SAME" -eq 1 ]; then
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

echo "MODE=${mode}  PATH=${path}"

# --- verdict ---
verdict="DOWN"
hint="Network looks dead. Fix connectivity first."

if [ "$mode" = "direct" ]; then
  verdict="OFF"
  hint="OneXray looks OFF (western egress = direct). Turn it ON to test the tunnel / hotel burn. vps443 from eSIM can stay OK even when hotel Wi‑Fi is burned."
elif [ "$MATCH_OK" -eq 1 ] && [ "$VPS443_OK" -eq 1 ] && [ "$WEST_OK" -eq 1 ]; then
  verdict="OK"
  if [ "$ESIMISH" -eq 1 ]; then
    hint="Tunnel works on this path (ipip looks like eSIM breakout, not hotel China). This does NOT clear a hotel burn — retest: hotel Wi‑Fi + OneXray ON."
  elif [ "$SPLIT_OK" -eq 0 ]; then
    hint="Tunnel OK. (no split seen — Custom Routing / GeoData if you need CN direct.)"
  else
    hint="Tunnel OK on this path — no renew needed from here."
  fi
elif [ "$mode" = "other-egress" ] && [ "$WEST_OK" -eq 1 ]; then
  verdict="ROUTING"
  hint="Western net works but egress ≠ this VPS (wrong/old OneXray link, or Xray off + eSIM breakout). Not a renew signal by itself."
elif [ "$CN_OK" -eq 1 ] && [ "$VPS443_OK" -eq 0 ]; then
  verdict="BURNED?"
  hint="Direct OK; VPS:443 dead from here. If this is hotel Wi‑Fi (not only eSIM), confirm box then task vpn:provision:renew-ip."
elif [ "$CN_OK" -eq 1 ] && [ "$MATCH_OK" -eq 0 ] && [ "$IPIFY_OK" -eq 0 ]; then
  verdict="BURNED?"
  hint="Direct OK; Western egress failed. Hotel + OneXray on: if still dead → renew (§6.1)."
elif [ "$CN_OK" -eq 0 ] && [ "$WEST_OK" -eq 0 ]; then
  verdict="DOWN"
  hint="Direct + Western both failed. Captive portal / radio first."
else
  verdict="TUNNEL"
  hint="Unclear. OneXray on + hotel Wi‑Fi, then re-run."
fi

echo "VERDICT=${verdict}"
echo "${hint}"

if [ "$verdict" = "OK" ]; then
  exit 0
fi
exit 1
