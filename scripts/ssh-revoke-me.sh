#!/usr/bin/env bash
# Remove every ssh-allow-me rule (by description marker) from every
# iac-managed Hetzner firewall. Standing (home) allowlist rules carry no
# marker and are never touched.
#
# Deletes each marked rule as a whole (all source_ips together). Per-IP
# delete-rule calls fail when a travel rule holds more than one CIDR.
set -euo pipefail

MARKER="iac-travel-allow-me"
LABEL="iac_managed=true"

FIREWALLS=$(hcloud firewall list -l "$LABEL" -o noheader -o columns=name)
if [ -z "$FIREWALLS" ]; then
  echo "No firewalls labelled ${LABEL} found — nothing to do."
  exit 0
fi

REMOVED=0
FAILED=0
for FW in $FIREWALLS; do
  RULES_JSON=$(hcloud firewall describe "$FW" -o json)
  RULE_COUNT=$(echo "$RULES_JSON" | jq -r --arg m "$MARKER" \
    '[.rules[] | select(.description == $m)] | length')
  if [ "$RULE_COUNT" -eq 0 ]; then
    echo "⏭️  ${FW}: no travel rules"
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
  echo "⚠️  Removed ${REMOVED} travel rule(s); some deletes failed." >&2
  exit 1
fi
echo "✅ Removed ${REMOVED} travel rule(s). Standing (home) rules untouched."
