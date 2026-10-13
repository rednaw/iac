#!/usr/bin/env bash
# Hotel smoke (Mac, OneXray ON + Custom Routing): binary works? / renew?
#   task vpn:smoke
#
# Exit 0 = OK. Non-zero = broken; last line is VERDICT=…
# Optional: VPN_DEST=…  EXPECT_IP=… (skip hcloud)
set -euo pipefail

VPN_DEST="${VPN_DEST:-amateurkunstamstelveen.nl}"
EXPECT_IP="${EXPECT_IP:-}"
TIMEOUT="${TIMEOUT:-12}"

ok() { printf '  %-12s OK   %s\n' "$1" "${2:-}"; }
fail() { printf '  %-12s FAIL %s\n' "$1" "${2:-}"; }

curl_ok() {
  # usage: curl_ok URL [curl args…]
  local url=$1; shift
  curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$@" -o /dev/null "$url" 2>/dev/null
}

http_code() {
  local url=$1; shift
  curl -4 -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
    -o /dev/null -w '%{http_code}' "$@" "$url" 2>/dev/null || echo "000"
}

if [ -z "$EXPECT_IP" ]; then
  EXPECT_IP=$(task hostkeys:ip -- vpn 2>/dev/null || true)
fi

echo "smoke (OneXray on; dest=${VPN_DEST}${EXPECT_IP:+; expect=${EXPECT_IP}})"
echo ""

# --- checks ---
IPIFY=""
CN_LINE=""
CN_OK=0
WEST_OK=0
VPS443_OK=0
IPIFY_OK=0
MATCH_OK=0
SPLIT_OK=0

if IPIFY=$(curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" https://api.ipify.org 2>/dev/null) \
  && [[ "$IPIFY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IPIFY_OK=1
  ok "ipify" "$IPIFY"
else
  fail "ipify" "no Western egress (OneXray off/down, or VPS unreachable)"
  IPIFY=""
fi

if [ -n "$EXPECT_IP" ] && [ "$IPIFY_OK" -eq 1 ]; then
  if [ "$IPIFY" = "$EXPECT_IP" ]; then
    MATCH_OK=1
    ok "match" "ipify = VPS"
  else
    fail "match" "ipify ${IPIFY} ≠ VPS ${EXPECT_IP}"
  fi
elif [ -z "$EXPECT_IP" ]; then
  echo "  match        SKIP (no EXPECT_IP / hcloud)"
fi

if CN_LINE=$(curl -4 -fsS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" https://myip.ipip.net 2>/dev/null); then
  CN_OK=1
  ok "ipip" "$CN_LINE"
else
  fail "ipip" "CN direct broken (hotel net?)"
fi

if [ "$IPIFY_OK" -eq 1 ] && [ "$CN_OK" -eq 1 ]; then
  if echo "$CN_LINE" | grep -qF "$IPIFY"; then
    fail "split" "ipip == ipify — Custom Routing / GeoData? (not a renew signal)"
  else
    SPLIT_OK=1
    ok "split" "CN direct ≠ VPS egress"
  fi
fi

PROBE_IP="${EXPECT_IP:-$IPIFY}"
if [ -n "$PROBE_IP" ]; then
  code=$(http_code "https://${VPN_DEST}/" --resolve "${VPN_DEST}:443:${PROBE_IP}")
  if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
    VPS443_OK=1
    ok "vps443" "HTTP ${code} via ${PROBE_IP} as ${VPN_DEST}"
  else
    fail "vps443" "HTTP ${code} (hotel→VPS:443 dead? burned?)"
  fi
else
  fail "vps443" "no IP to probe"
fi

if curl_ok "https://www.cloudflare.com/cdn-cgi/trace"; then
  WEST_OK=1
  ok "western" "cloudflare via VPN"
else
  fail "western" "HTTPS via VPN failed"
fi

if curl_ok "https://www.baidu.com/"; then
  CN_OK=1
  ok "baidu" "CN direct"
else
  CN_OK=0
  fail "baidu" "CN direct failed"
fi

echo ""

# --- verdict (renew-focused) ---
# OK:       egress = this VPS (when known), vps443 + western OK — no renew
# BURNED?:  CN direct OK, tunnel/VPS path dead — confirm box, then renew
# ROUTING:  tunnel up but wrong egress IP / inverted split
# DOWN:     CN + Western both dead (hotel)
# TUNNEL:   unclear client/tunnel failure

verdict="DOWN"
hint="Hotel network looks dead (CN + Western failed). Fix Wi‑Fi / captive portal first."

tunnel_up=0
if [ "$IPIFY_OK" -eq 1 ] && [ "$VPS443_OK" -eq 1 ] && [ "$WEST_OK" -eq 1 ]; then
  tunnel_up=1
fi

if [ "$tunnel_up" -eq 1 ]; then
  if [ -n "$EXPECT_IP" ] && [ "$MATCH_OK" -eq 0 ]; then
    verdict="ROUTING"
    hint="Western path works but egress ≠ this VPS. Wrong/old link in OneXray?"
  else
    verdict="OK"
    if [ "$SPLIT_OK" -eq 0 ]; then
      hint="No renew needed. (split not seen — enable Custom Routing + GeoData on hotel Mac if WeChat should go direct.)"
    else
      hint="No renew needed."
    fi
  fi
elif [ "$CN_OK" -eq 1 ] && { [ "$IPIFY_OK" -eq 0 ] || [ "$VPS443_OK" -eq 0 ] || [ "$WEST_OK" -eq 0 ]; }; then
  verdict="BURNED?"
  hint="CN direct OK; VPS path dead from here. Confirm box via eSIM/SSH, then task vpn:provision:renew-ip (§6.1)."
elif [ "$CN_OK" -eq 0 ] && [ "$WEST_OK" -eq 1 ]; then
  verdict="ROUTING"
  hint="Western OK but CN direct failed — routing inverted or GeoData missing?"
elif [ "$CN_OK" -eq 0 ] && [ "$WEST_OK" -eq 0 ]; then
  verdict="DOWN"
  hint="Hotel network looks dead (CN + Western failed). Fix Wi‑Fi / captive portal first."
else
  verdict="TUNNEL"
  hint="OneXray off/broken, or partial failure. Toggle VPN, re-import vpn:config, retry."
fi

echo "VERDICT=${verdict}"
echo "${hint}"

if [ "$verdict" = "OK" ]; then
  exit 0
fi
exit 1
