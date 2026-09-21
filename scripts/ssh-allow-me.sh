#!/usr/bin/env bash
# Travel only (skip at home): allow the current public IPv4 (/32, TCP/22) on
# every iac-managed Hetzner firewall (label iac_managed=true) in one go.
#
# The extra rule lives only in Hetzner — not Terraform, not SOPS, not git —
# so the next *:provision:apply on a box wipes that box's extra rule (rerun
# this script). Rules carry a description marker so ssh-revoke-me never
# touches the standing (home) allowlist.
#
# CGNAT caveat (roaming eSIMs): the detected IPv4 can differ from the SSH
# egress IP or rotate per flow. If SSH still refuses afterwards: rerun once,
# then fall back to the Hetzner Console (web console, or add the /32 by hand
# with the same marker).
set -euo pipefail

MARKER="iac-travel-allow-me"
LABEL="iac_managed=true"

MYIP=$(curl -4 -fsS --max-time 10 https://api.ipify.org || true)
if ! [[ "$MYIP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ No public IPv4 detected (got: '${MYIP:-nothing}'). Refusing — check connectivity (-4)." >&2
  exit 1
fi
echo "🌍 Public IPv4: ${MYIP}"

if hcloud server list -o noheader -o columns=ipv4 | grep -Fxq "$MYIP"; then
  echo "❌ ${MYIP} is an iac server address — refusing to allowlist it." >&2
  exit 1
fi

FIREWALLS=$(hcloud firewall list -l "$LABEL" -o noheader -o columns=name)
if [ -z "$FIREWALLS" ]; then
  echo "❌ No firewalls labelled ${LABEL} found (provision with the updated server module first)." >&2
  exit 1
fi

for FW in $FIREWALLS; do
  if hcloud firewall describe "$FW" -o json \
    | jq -e --arg ip "${MYIP}/32" \
        '.rules[] | select(.direction == "in" and .protocol == "tcp" and .port == "22")
                  | select(.source_ips[] == $ip)' >/dev/null; then
    echo "⏭️  ${FW}: ${MYIP}/32 already allowed — skipping"
    continue
  fi
  hcloud firewall add-rule "$FW" --direction in --protocol tcp --port 22 \
    --source-ips "${MYIP}/32" --description "$MARKER" >/dev/null
  echo "✅ ${FW}: added ${MYIP}/32"
done

echo ""
echo "⚠️  Extra rules are Hetzner-only: the next *:provision:apply on a box WIPES its extra rule."
echo "   Done for the day / back home: task ssh-revoke-me"
