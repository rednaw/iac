#!/usr/bin/env bash
# Idempotent hcloud provision for a REALITY box: server + managed primary IPv4
# + firewall, all named after BOX_NAME (vpn → vpn / vpn-v4 / vpn-firewall).
#
#   present  Create whatever is missing. Converge firewall standing rules
#            (ICMP + 443 only — no standing SSH) and keep ssh:allow marker
#            rules. Never resizes, rebuilds, or re-addresses an existing
#            server — renew owns the IPv4 once the box exists.
#   absent   Delete server, every <name>-v4* / <name>-hold-* / <name>-burned-*
#            primary IPv4, and the firewall. Missing pieces are skipped.
#
# SSH: default deny. Only task <name>:ssh:allow (description
# "Allow SSH from trusted IPs") opens port 22. present does not read a
# standing SSH allowlist from secrets.
#
# Preconditions: cwd = iac repo root; HCLOUD_TOKEN for the box's project.
# present also needs BOX_SSH_KEYS_JSON (JSON list of Hetzner SSH key IDs).
set -euo pipefail

ACTION="${1:-}"
NAME="${BOX_NAME:-vpn}"
LOCATION="${BOX_LOCATION:-nbg1}"
SERVER_TYPE="${BOX_SERVER_TYPE:-cx23}"
IMAGE="${BOX_IMAGE:-ubuntu-24.04}"
IP_NAME="${NAME}-v4"
FW_NAME="${NAME}-firewall"
SSH_ALLOW_MARKER="Allow SSH from trusted IPs"

: "${HCLOUD_TOKEN:?HCLOUD_TOKEN must be set (source the box secrets script first)}"

server_exists() { hcloud server list -o noheader -o columns=name | grep -Fxq "$NAME"; }
firewall_exists() { hcloud firewall list -o noheader -o columns=name | grep -Fxq "$FW_NAME"; }
primary_ip_exists() { hcloud primary-ip list -o noheader -o columns=name | grep -Fxq "$IP_NAME"; }

# Standing = ICMP + REALITY only. No SSH rule → default deny until ssh:allow.
standing_rules() {
  jq -n '[
    {direction: "in", protocol: "icmp", source_ips: ["0.0.0.0/0", "::/0"],
     description: "Allow ping from anywhere"},
    {direction: "in", protocol: "tcp", port: "443", source_ips: ["0.0.0.0/0", "::/0"],
     description: "REALITY (VLESS over TLS)"}
  ]'
}

present() {
  : "${BOX_SSH_KEYS_JSON:?BOX_SSH_KEYS_JSON required}"
  if [ "$(jq 'length' <<<"$BOX_SSH_KEYS_JSON")" -eq 0 ]; then
    echo "❌ ssh_keys must be a non-empty list." >&2
    exit 1
  fi

  local rules
  rules=$(standing_rules)

  if firewall_exists; then
    local allow_me
    allow_ssh=$(hcloud firewall describe "$FW_NAME" -o json | jq --arg m "$SSH_ALLOW_MARKER" \
      '[.rules[] | select(.description == $m)
        | {direction, protocol, port, source_ips, description}]')
    echo "🔁 ${FW_NAME}: converge standing (no SSH); keeping $(jq length <<<"$allow_ssh") trusted-SSH rule(s)"
    jq -n --argjson a "$rules" --argjson b "$allow_ssh" '$a + $b' \
      | hcloud firewall replace-rules --rules-file - "$FW_NAME" >/dev/null
  else
    echo "➕ ${FW_NAME}: create (SSH closed until: task ${NAME}:ssh:allow)"
    hcloud firewall create --name "$FW_NAME" \
      --label "purpose=${NAME}" --label iac_managed=true --label managed_by=iac \
      --rules-file - <<<"$rules" >/dev/null
  fi

  if server_exists; then
    local fw_id attached
    fw_id=$(hcloud firewall describe "$FW_NAME" -o json | jq -r '.id')
    attached=$(hcloud server describe "$NAME" -o json \
      | jq --argjson id "$fw_id" '[.public_net.firewalls[]? | select(.id == $id)] | length')
    if [ "$attached" -eq 0 ]; then
      echo "🔗 ${FW_NAME}: attach to ${NAME}"
      hcloud firewall apply-to-resource --type server --server "$NAME" "$FW_NAME" >/dev/null
    fi
    local ip
    ip=$(hcloud server ip "$NAME" 2>/dev/null || true)
    if [ -z "$ip" ]; then
      echo "⚠️  ${NAME} exists but has no IPv4 (mid-renew?). Not touching it — finish or rerun renew." >&2
      exit 1
    fi
    echo "✅ ${NAME} already present (${ip}); server left as-is."
    return 0
  fi

  if primary_ip_exists; then
    local assignee
    assignee=$(hcloud primary-ip describe "$IP_NAME" -o json | jq -r '.assignee_id // empty')
    if [ -n "$assignee" ] && [ "$assignee" != "0" ]; then
      echo "❌ ${IP_NAME} is assigned to resource ${assignee}, but server ${NAME} does not exist." >&2
      exit 1
    fi
    echo "♻️  ${IP_NAME}: reuse unassigned"
  else
    echo "➕ ${IP_NAME}: create (${LOCATION})"
    hcloud primary-ip create --type ipv4 --name "$IP_NAME" --location "$LOCATION" \
      --auto-delete=false --label "purpose=${NAME}" --label managed_by=iac >/dev/null
  fi

  local key_args=()
  while IFS= read -r key; do
    key_args+=(--ssh-key "$key")
  done < <(jq -r '.[] | tostring' <<<"$BOX_SSH_KEYS_JSON")

  echo "➕ ${NAME}: create (${SERVER_TYPE}, ${IMAGE}, ${LOCATION})"
  hcloud server create --name "$NAME" --type "$SERVER_TYPE" --image "$IMAGE" \
    --location "$LOCATION" --primary-ipv4 "$IP_NAME" --firewall "$FW_NAME" \
    "${key_args[@]}" --label "purpose=${NAME}" --label managed_by=iac >/dev/null

  local ip
  ip=$(hcloud server ip "$NAME")
  ssh-keygen -R "$ip" -f "${HOME}/.ssh/known_hosts" -q 2>/dev/null || true
  echo "✅ ${NAME} created (${ip}). SSH closed until: task ${NAME}:ssh:allow"
}

absent() {
  local ip=""
  if server_exists; then
    ip=$(hcloud server ip "$NAME" 2>/dev/null || true)
    echo "🗑️  ${NAME}: delete server"
    hcloud server delete "$NAME" >/dev/null
  else
    echo "⏭️  ${NAME}: no server"
  fi

  local ids
  ids=$(hcloud primary-ip list -o json | jq -r --arg n "$NAME" '
    .[] | select(.type == "ipv4")
        | select(.name | test("^" + $n + "-(v4($|-new-)|hold-|burned-)"))
        | "\(.id) \(.name) \(.ip)"')
  if [ -z "$ids" ]; then
    echo "⏭️  no ${NAME} primary IPv4s"
  fi
  while read -r id name pip; do
    [ -n "${id:-}" ] || continue
    echo "🗑️  primary IPv4 ${name} (${pip})"
    hcloud primary-ip delete "$id" >/dev/null
  done <<<"$ids"

  if firewall_exists; then
    echo "🗑️  ${FW_NAME}: delete"
    local n=0
    until hcloud firewall delete "$FW_NAME" >/dev/null 2>&1; do
      n=$((n + 1))
      if [ "$n" -ge 10 ]; then
        echo "❌ Could not delete ${FW_NAME} (still attached?)" >&2
        exit 1
      fi
      sleep 3
    done
  else
    echo "⏭️  ${FW_NAME}: none"
  fi

  if [ -n "$ip" ]; then
    ssh-keygen -R "$ip" -f "${HOME}/.ssh/known_hosts" -q 2>/dev/null || true
  fi
  echo "✅ ${NAME} absent."
}

case "$ACTION" in
  present) present ;;
  absent) absent ;;
  *)
    echo "Usage: $0 present|absent" >&2
    exit 1
    ;;
esac
