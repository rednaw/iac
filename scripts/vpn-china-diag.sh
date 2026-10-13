#!/usr/bin/env bash
# Hotel / travel smoke: OneXray on + Custom Routing.
# Run on the Mac (not the VPS):  bash scripts/vpn-china-diag.sh
#
# Expect: ipify = Hetzner; ipip = China hotel; baidu fast; google/cf slower.
# Optional: VPN_DEST=…  SAMPLES=5  SKIP_DOWNLOAD=1
set -euo pipefail

SAMPLES="${SAMPLES:-3}"
VPN_DEST="${VPN_DEST:-amateurkunstamstelveen.nl}"
SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-0}"

fmt_full='dns:%{time_namelookup} connect:%{time_connect} tls:%{time_appconnect} ttfb:%{time_starttransfer} total:%{time_total}'
fmt_vps='connect:%{time_connect} tls:%{time_appconnect} total:%{time_total} code:%{http_code}'

hr() { printf '\n── %s ──\n' "$1"; }

curl_time() {
  local label=$1; shift
  # shellcheck disable=SC2034
  local out
  if ! out=$(curl -4 -sS -o /dev/null -w "$fmt_full" --connect-timeout 15 "$@" 2>&1); then
    printf '%s FAILED: %s\n' "$label" "$out"
    return 0
  fi
  printf '%s %s\n' "$label" "$out"
}

hr "egress (expect Hetzner VPS)"
IPIFY=$(curl -4 -fsS --connect-timeout 10 https://api.ipify.org || true)
if [[ "$IPIFY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ipify: ${IPIFY}"
else
  echo "ipify: FAILED (${IPIFY:-empty}) — is OneXray on?"
  exit 1
fi

hr "CN direct (expect hotel / China ISP — NOT ${IPIFY})"
if IPIP=$(curl -4 -fsS --connect-timeout 10 https://myip.ipip.net 2>&1); then
  echo "ipip: ${IPIP}"
else
  echo "ipip: FAILED (${IPIP})"
fi

hr "VPS 443 tax (${SAMPLES}× → ${IPIFY} as ${VPN_DEST})"
for i in $(seq 1 "$SAMPLES"); do
  if ! out=$(curl -4 -sS -o /dev/null -w "$fmt_vps" --connect-timeout 15 \
      --resolve "${VPN_DEST}:443:${IPIFY}" \
      "https://${VPN_DEST}/" 2>&1); then
    echo "vps_${i} FAILED: ${out}"
  else
    echo "vps_${i} ${out}"
  fi
done

hr "latency classes (${SAMPLES}× each)"
for i in $(seq 1 "$SAMPLES"); do
  curl_time "baidu_direct_${i}" https://www.baidu.com/
  curl_time "google_vpn_${i}"   https://www.google.com/
  curl_time "cf_vpn_${i}"       https://www.cloudflare.com/cdn-cgi/trace
done

if [ "$SKIP_DOWNLOAD" != "1" ]; then
  hr "throughput (5 MiB via VPN vs tiny CN fetch)"
  curl -4 -sS -o /dev/null --connect-timeout 30 \
    -w 'vpn_5MiB speed_Bps:%{speed_download} time:%{time_total} size:%{size_download}\n' \
    "https://speed.cloudflare.com/__down?bytes=5242880" || echo "vpn_5MiB FAILED"
  curl -4 -sS -o /dev/null --connect-timeout 15 \
    -w 'baidu_body speed_Bps:%{speed_download} time:%{time_total} size:%{size_download}\n' \
    https://www.baidu.com/ || echo "baidu_body FAILED"
fi

hr "how to read"
cat <<EOF
- ipify = VPS, ipip = China  → Custom Routing split OK
- ipip = same as ipify       → everything via VPS (routing not selected / no GeoData)
- baidu ≪ google/cf          → expected penalty for Western-via-DE
- vps tls ~steady multi-sec  → hotel→Nuremberg floor (connect≈0 via TUN is normal)
- vps code 200               → REALITY impostor OK
EOF
