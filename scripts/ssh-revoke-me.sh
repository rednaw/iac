#!/usr/bin/env bash
# Remove every ssh-allow-me rule (by description marker) from every
# iac-managed Hetzner firewall. Standing (home) allowlist rules carry no
# marker and are never touched.
set -euo pipefail

MARKER="iac-travel-allow-me"
LABEL="iac_managed=true"

FIREWALLS=$(hcloud firewall list -l "$LABEL" -o noheader -o columns=name)
if [ -z "$FIREWALLS" ]; then
  echo "No firewalls labelled ${LABEL} found — nothing to do."
  exit 0
fi

REMOVED=0
for FW in $FIREWALLS; do
  IPS=$(hcloud firewall describe "$FW" -o json \
    | jq -r --arg m "$MARKER" '.rules[] | select(.description == $m) | .source_ips[]')
  if [ -z "$IPS" ]; then
    echo "⏭️  ${FW}: no travel rules"
    continue
  fi
  for IP in $IPS; do
    hcloud firewall delete-rule "$FW" --direction in --protocol tcp --port 22 \
      --source-ips "$IP" --description "$MARKER" >/dev/null
    echo "🗑️  ${FW}: removed ${IP}"
    REMOVED=$((REMOVED + 1))
  done
done

echo ""
echo "✅ Removed ${REMOVED} travel rule(s). Standing (home) rules untouched."
