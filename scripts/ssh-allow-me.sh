#!/usr/bin/env bash
# Travel only (skip at home): allow the current public IPv4 (/32, TCP/22) on
# every iac-managed Hetzner firewall (label iac_managed=true) in one go.
#
# The extra rule lives only in Hetzner — not Terraform, not SOPS, not git —
# so the next *:provision:apply on a box wipes that box's extra rule (rerun
# this script). Rules carry a description marker so ssh-revoke-me never
# touches the standing (home) allowlist.
#
# CGNAT caveat (roaming / travel eSIMs): the detected IPv4 can differ from the
# SSH egress IP or rotate per flow. If SSH still refuses afterwards: rerun
# once, then fall back to the Hetzner Console (web console, or add the /32 by
# hand with the same marker).
set -euo pipefail

MARKER="iac-travel-allow-me"
LABEL="iac_managed=true"

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

MYIP=$(detect_public_ipv4 || true)
if ! [[ "${MYIP:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ No public IPv4 detected from ipify/ifconfig.me/icanhazip. Refusing — check connectivity (-4)." >&2
  exit 1
fi
echo "🌍 Public IPv4: ${MYIP}"

if ! hcloud firewall list -l "$LABEL" -o noheader -o columns=name >/dev/null; then
  echo "❌ hcloud cannot list firewalls (token / context?). Fix hcloud auth, then retry." >&2
  exit 1
fi

if hcloud server list -o noheader -o columns=ipv4 | grep -Fxq "$MYIP"; then
  echo "❌ ${MYIP} is an iac server address — refusing to allowlist it." >&2
  echo "   OneXray (or another tunnel) on? Turn it off so detection sees the hotel/eSIM IPv4, then retry." >&2
  exit 1
fi

FIREWALLS=$(hcloud firewall list -l "$LABEL" -o noheader -o columns=name)
if [ -z "$FIREWALLS" ]; then
  echo "❌ No firewalls labelled ${LABEL} found (provision with the updated server module first)." >&2
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
    # Already covered (standing home rule or a prior travel rule).
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
    # Confirm the rule landed (API can succeed without the rule matching later SSH).
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
echo "⚠️  Extra rules are Hetzner-only: the next *:provision:apply on a box WIPES its extra rule."
echo "   Done for the day / back home: task ssh-revoke-me"
echo "   Summary: added=${ADDED} skipped=${SKIPPED}"
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
