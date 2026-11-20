#!/usr/bin/env bash
# VPN-family travel SSH: allow current public IPv4 (/32, TCP/22) on one
# purpose's firewalls (purpose=vpn|gate). Platform is never a valid purpose.
#
#   task vpn:ssh:allow | task gate:ssh:allow
#   bash scripts/ssh-allow.sh vpn|gate
#
# Loads that purpose's secrets (vpn.yml / gate.yml). Description marker
# "Allow SSH from trusted IPs"; kept across provision:present. Legacy gate
# TF apply still wipes markers.
set -euo pipefail

PURPOSE="${1:-}"
MARKER="Allow SSH from trusted IPs"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${SECRETS_DIR:-$(realpath -m "${ROOT}/../secrets")}"
SOPS_KEY_FILE="${SOPS_KEY_FILE:-${HOME}/.config/sops/age/keys.txt}"

usage() {
  echo "Usage: task vpn:ssh:allow | task gate:ssh:allow" >&2
  exit 1
}

case "$PURPOSE" in
  vpn|gate) ;;
  *) usage ;;
esac

detect_public_ipv4() {
  local url ip
  for url in \
    https://api.ipify.org \
    https://ifconfig.me/ip \
    https://ipv4.icanhazip.com
  do
    ip=$(curl -4 -fsS --max-time 8 "$url" 2>/dev/null | tr -d '[:space:]' || true)
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
  done
  return 1
}

if [ ! -f "$SOPS_KEY_FILE" ]; then
  echo "❌ Missing age key at ${SOPS_KEY_FILE}" >&2
  exit 1
fi
export SOPS_KEY_FILE SECRETS_DIR

case "$PURPOSE" in
  vpn)
    # shellcheck disable=SC1091
    . "${ROOT}/scripts/vpn-secrets.sh"
    ;;
  gate)
    # shellcheck disable=SC1091
    . "${ROOT}/scripts/gate-tf-secrets.sh"
    ;;
esac

MYIP=$(detect_public_ipv4 || true)
if ! [[ "${MYIP:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ No public IPv4 detected. Check connectivity (-4)." >&2
  exit 1
fi
echo "🌍 Public IPv4: ${MYIP} → purpose=${PURPOSE}"

if hcloud server list -o noheader -o columns=ipv4 2>/dev/null | grep -Fxq "$MYIP"; then
  echo "❌ ${MYIP} is a server address in this project — refusing (OneXray on?)." >&2
  exit 1
fi

FIREWALLS=$(hcloud firewall list -l "purpose=${PURPOSE}" -o noheader -o columns=name | awk 'NF')
if [ -z "$FIREWALLS" ]; then
  echo "❌ No firewall with purpose=${PURPOSE} in this project." >&2
  if [ "$PURPOSE" = "vpn" ]; then
    echo "   Create first: task vpn:provision:present" >&2
  fi
  exit 1
fi

ADDED=0
SKIPPED=0
FAILED=0
for FW in $FIREWALLS; do
  RULES_JSON=$(hcloud firewall describe "$FW" -o json)

  if echo "$RULES_JSON" | jq -e --arg ip "${MYIP}/32" \
      '.rules[] | select(.direction == "in" and .protocol == "tcp" and .port == "22")
                | select(.source_ips[] == $ip)' >/dev/null; then
    if echo "$RULES_JSON" | jq -e --arg ip "${MYIP}/32" --arg m "$MARKER" \
        '.rules[] | select(.direction == "in" and .protocol == "tcp" and .port == "22")
                  | select(.source_ips[] == $ip)
                  | select(.description != $m)' >/dev/null; then
      echo "⏭️  ${FW}: ${MYIP}/32 already on standing allowlist — skipping"
    else
      echo "⏭️  ${FW}: ${MYIP}/32 already allowed (travel) — skipping"
    fi
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if hcloud firewall add-rule "$FW" --direction in --protocol tcp --port 22 \
      --source-ips "${MYIP}/32" --description "$MARKER" >/dev/null; then
    if hcloud firewall describe "$FW" -o json | jq -e --arg ip "${MYIP}/32" --arg m "$MARKER" \
        '.rules[] | select(.description == $m) | select(.source_ips[] == $ip)' >/dev/null; then
      echo "✅ ${FW}: added ${MYIP}/32"
      ADDED=$((ADDED + 1))
    else
      echo "❌ ${FW}: add-rule returned OK but ${MYIP}/32 with marker not found" >&2
      FAILED=1
    fi
  else
    echo "❌ ${FW}: failed to add ${MYIP}/32" >&2
    FAILED=1
  fi
done

echo ""
echo "⚠️  Marker rules are Hetzner-only. vpn:provision:present keeps them; legacy gate TF apply wipes them."
echo "   Done for the day: task ${PURPOSE}:ssh:deny"
echo "   Summary: added=${ADDED} skipped=${SKIPPED}"
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
