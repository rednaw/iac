#!/usr/bin/env bash
# Burned IP renew:
#   1. Create primary IPv4 (old still assigned).
#   2. If address is denylisted / current → keep it unassigned (do not delete —
#      Hetzner sticky-recycles the same IP if you free it mid-loop).
#   3. Repeat until a fresh non-burned IP.
#   4. Move server onto the fresh IP.
#   5. Delete the old live IP and every IP held during this create loop.
#
# Denylist: .vpn-burned-ips (gitignored) — append old IP on renew; reject as live.
# Brief poweroff during move. Disk kept.
#
# Preconditions: cwd = iac repo root; hcloud auth; TF_VAR_* set.
set -euo pipefail

SERVER="${VPN_SERVER_NAME:-vpn}"
TF_DIR="${VPN_TF_DIR:-terraform/vpn}"
IP_NAME="${VPN_PRIMARY_IP_NAME:-vpn-v4}"
POWER_WAIT_MAX="${VPN_RENEW_POWER_WAIT_MAX:-90}"
CREATE_MAX="${VPN_RENEW_CREATE_MAX:-15}"
BURNED_FILE="${VPN_BURNED_IPS_FILE:-.vpn-burned-ips}"
HOLD_PREFIX="${VPN_HOLD_IP_PREFIX:-vpn-hold-}"

# IDs of primary IPs held this run (denylisted creates); deleted after successful move.
HELD_IDS=()

wait_status() {
  local want=$1 st n=0
  while [ "$n" -lt "$POWER_WAIT_MAX" ]; do
    st=$(hcloud server describe "$SERVER" -o format='{{.Status}}')
    if [ "$st" = "$want" ]; then
      return 0
    fi
    n=$((n + 1))
    sleep 2
  done
  echo "❌ Server ${SERVER} did not reach status=${want} in time (last=${st:-unknown})" >&2
  return 1
}

is_burned() {
  local ip=$1
  [ -f "$BURNED_FILE" ] || return 1
  grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' "$BURNED_FILE" | grep -Fxq "$ip"
}

remember_burned() {
  local ip=$1
  touch "$BURNED_FILE"
  if is_burned "$ip"; then
    return 0
  fi
  printf '%s\n' "$ip" >>"$BURNED_FILE"
  echo "   denylist += ${ip} (${BURNED_FILE})"
}

hold_for_loop() {
  local id=$1 ip=$2
  local hold_name
  hold_name="${HOLD_PREFIX}$(echo "$ip" | tr '.' '-')"
  hcloud primary-ip update --name "$hold_name" "$id" >/dev/null || true
  remember_burned "$ip"
  HELD_IDS+=("$id")
  echo "   holding ${ip} as ${hold_name} until renew finishes (id=${id})"
}

delete_held() {
  local id
  for id in "${HELD_IDS[@]+"${HELD_IDS[@]}"}"; do
    echo "   delete held id=${id}"
    hcloud primary-ip delete "$id" || true
  done
  HELD_IDS=()
}

old_ip=$(hcloud server ip "$SERVER") || {
  echo "❌ No IPv4 on server ${SERVER}" >&2
  exit 1
}
old_id=$(hcloud server describe "$SERVER" -o json | yq -r '.public_net.ipv4.id')
if ! [[ "$old_id" =~ ^[0-9]+$ ]]; then
  echo "❌ Could not read primary IPv4 id for ${SERVER}" >&2
  exit 1
fi
location=$(hcloud primary-ip describe "$old_id" -o json | yq -r '.location.name')
if [ -z "$location" ] || [ "$location" = "null" ]; then
  echo "❌ Could not read location of primary IP ${old_id}" >&2
  exit 1
fi

echo "🔁 Burned IP renew (create → hold burned → move → delete holds + old)"
echo "   server=${SERVER}  current=${old_ip} (id=${old_id})  location=${location}"
echo "   Disk kept; brief poweroff while swapping primary IPv4"
echo "   denylist=${BURNED_FILE}"
remember_burned "$old_ip"
echo ""

new_id=""
new_ip=""
new_name=""
attempt=1
while [ "$attempt" -le "$CREATE_MAX" ]; do
  ts=$(date -u +%Y%m%d%H%M%S)
  new_name="${IP_NAME}-new-${ts}-${attempt}"
  echo "—— create primary IPv4 ${new_name} (attempt ${attempt}/${CREATE_MAX}) ——"
  create_json=$(hcloud primary-ip create \
    --type ipv4 \
    --name "$new_name" \
    --location "$location" \
    --auto-delete=false \
    -o json)
  new_id=$(echo "$create_json" | yq -r '.primary_ip.id // .id')
  new_ip=$(echo "$create_json" | yq -r '.primary_ip.ip // .ip')
  if ! [[ "$new_id" =~ ^[0-9]+$ ]] || ! [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ primary-ip create failed to return id/ip: ${create_json}" >&2
    delete_held
    exit 1
  fi
  if [ "$new_ip" = "$old_ip" ] || is_burned "$new_ip"; then
    echo "⚠️  burned/current (${new_ip}) — keep held, create again…" >&2
    hold_for_loop "$new_id" "$new_ip"
    attempt=$((attempt + 1))
    continue
  fi
  echo "   fresh=${new_ip} (id=${new_id})"
  break
done
if [ "$attempt" -gt "$CREATE_MAX" ]; then
  echo "❌ No fresh IPv4 after ${CREATE_MAX} creates; deleting holds from this run…" >&2
  delete_held
  exit 1
fi

cleanup_on_fail() {
  echo "⚠️  Aborting — server left as-is; deleting holds from this run; new ${new_id} may need manual cleanup" >&2
  delete_held
}
trap cleanup_on_fail ERR

echo "—— poweroff ${SERVER} ——"
hcloud server poweroff "$SERVER"
wait_status off

echo "—— unassign ${old_ip} / assign ${new_ip} ——"
hcloud primary-ip unassign "$old_id"
hcloud primary-ip assign --server "$SERVER" "$new_id"

echo "—— poweron ${SERVER} ——"
hcloud server poweron "$SERVER"
wait_status running

cur_ip=$(hcloud server ip "$SERVER")
if [ "$cur_ip" != "$new_ip" ]; then
  echo "❌ Server IPv4 is ${cur_ip}, expected ${new_ip}" >&2
  exit 1
fi
trap - ERR

echo "—— delete old live IP ${old_ip} (id=${old_id}) ——"
hcloud primary-ip delete "$old_id" || true

echo "—— delete all IPs held during create loop ——"
delete_held

# Also drop leftover holds/burns from earlier runs (vpn-hold-* / vpn-burned-*).
echo "—— cleanup leftover vpn-hold-* / vpn-burned-* in project ——"
while read -r leftover_id; do
  [ -n "$leftover_id" ] || continue
  echo "   delete leftover id=${leftover_id}"
  hcloud primary-ip delete "$leftover_id" || true
done < <(hcloud primary-ip list -o json | yq -r '
  .[] | select(.assignee_id == null or .assignee_id == 0)
      | select(.name | test("^vpn-(hold|burned)-"))
      | .id')

echo "—— rename ${new_name} → ${IP_NAME} ——"
hcloud primary-ip update --name "$IP_NAME" "$new_id"

echo "—— sync Terraform state (best-effort; skip if TFC unreachable) ——"
if terraform -chdir="$TF_DIR" init -input=false >/dev/null 2>&1 \
  && terraform -chdir="$TF_DIR" state rm 'hcloud_primary_ip.v4' >/dev/null 2>&1 \
  && terraform -chdir="$TF_DIR" import -input=false 'hcloud_primary_ip.v4' "$new_id" >/dev/null 2>&1 \
  && terraform -chdir="$TF_DIR" apply -auto-approve -refresh-only -input=false \
       -target=hcloud_primary_ip.v4 \
       -target=module.server.hcloud_server.this >/dev/null 2>&1; then
  echo "   TF state updated"
else
  echo "⚠️  TF state NOT synced (no TFC / init failed). Live IP is still ${new_ip}." >&2
  echo "   From a path that reaches app.terraform.io later: re-run state fix or full vpn apply." >&2
fi

ssh-keygen -R "$old_ip" -f "${HOME}/.ssh/known_hosts" -q 2>/dev/null || true

echo ""
echo "✅ Primary IPv4 renewed: ${old_ip} → ${new_ip}"
echo "   Re-import / edit server address on every device (SSH not required)."
echo "   Burned addresses stay in ${BURNED_FILE}; held only during create, then deleted."
