#!/usr/bin/env bash
# Remove travel SSH rules (description "Allow SSH from trusted IPs") from one
# purpose's firewalls (purpose=platform|vpn|gate).
#
#   task platform|vpn|gate:ssh:deny
#   bash scripts/ssh-deny.sh platform|vpn|gate
set -euo pipefail

PURPOSE="${1:-}"
MARKER="Allow SSH from trusted IPs"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${SECRETS_DIR:-$(realpath -m "${ROOT}/../secrets")}"
SOPS_KEY_FILE="${SOPS_KEY_FILE:-${HOME}/.config/sops/age/keys.txt}"

usage() {
  echo "Usage: task platform|vpn|gate:ssh:deny" >&2
  exit 1
}

case "$PURPOSE" in
  platform|vpn|gate) ;;
  *) usage ;;
esac

if [ ! -f "$SOPS_KEY_FILE" ]; then
  echo "❌ Missing age key at ${SOPS_KEY_FILE}" >&2
  exit 1
fi
export SOPS_KEY_FILE SECRETS_DIR

case "$PURPOSE" in
  platform)
    # shellcheck disable=SC1091
    . "${ROOT}/scripts/platform-secrets.sh"
    ;;
  vpn)
    # shellcheck disable=SC1091
    . "${ROOT}/scripts/vpn-secrets.sh"
    ;;
  gate)
    # shellcheck disable=SC1091
    . "${ROOT}/scripts/gate-tf-secrets.sh"
    ;;
esac

FIREWALLS=$(hcloud firewall list -l "purpose=${PURPOSE}" -o noheader -o columns=name | awk 'NF')
if [ -z "$FIREWALLS" ]; then
  echo "No firewall with purpose=${PURPOSE} — nothing to do."
  exit 0
fi

REMOVED=0
FAILED=0
for FW in $FIREWALLS; do
  RULES_JSON=$(hcloud firewall describe "$FW" -o json)
  if [ "$(echo "$RULES_JSON" | jq -r --arg m "$MARKER" \
      '[.rules[] | select(.description == $m)] | length')" -eq 0 ]; then
    echo "⏭️  ${FW}: no trusted-SSH rules"
    continue
  fi
  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    IPS_CSV=$(echo "$rule" | jq -r '.source_ips | join(",")')
    IPS_DISPLAY=$(echo "$rule" | jq -r '.source_ips | join(" ")')
    if hcloud firewall delete-rule "$FW" --direction in --protocol tcp --port 22 \
        --source-ips "$IPS_CSV" --description "$MARKER" >/dev/null; then
      echo "🗑️  ${FW}: removed ${IPS_DISPLAY}"
      REMOVED=$((REMOVED + 1))
    else
      echo "❌ ${FW}: failed to remove ${IPS_DISPLAY}" >&2
      FAILED=1
    fi
  done < <(echo "$RULES_JSON" | jq -c --arg m "$MARKER" \
    '.rules[] | select(.description == $m)')
done

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo "⚠️  Removed ${REMOVED} rule(s) on ${PURPOSE}; some deletes failed." >&2
  exit 1
fi
echo "✅ Removed ${REMOVED} trusted-SSH rule(s) on ${PURPOSE}."
