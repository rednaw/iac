#!/usr/bin/env bash
# Source this from the IaC repo root to populate TF_VAR_* for terraform/vpn
# from the private secrets sibling (../secrets/vpn.yml) only.
#
# Also exports HCLOUD_TOKEN from that file so hcloud/hostkeys hit the intended
# project (Default / platform mirror for the dev box), overwriting any ambient
# token in the shell.
#
# Never reads infra.yml for Hetzner or vpn_* emit fields. TFC org/token still
# come from infra.yml via _terraform:init (separate).

: "${SOPS_KEY_FILE:?SOPS_KEY_FILE must be exported before sourcing this script}"

if [ -z "${SECRETS_DIR:-}" ]; then
  _here="${BASH_SOURCE[0]-}"
  [ -n "${_here}" ] || _here="$0"
  _IAC_ROOT="$(cd "$(dirname "${_here}")/.." && pwd)"
  SECRETS_DIR="$(realpath -m "${_IAC_ROOT}/../secrets")"
  unset _here _IAC_ROOT
fi
SECRETS_VPN="${SECRETS_VPN:-${SECRETS_DIR}/vpn.yml}"
if [ ! -f "${SECRETS_VPN}" ]; then
  echo "❌ Encrypted vpn secrets missing: ${SECRETS_VPN}" >&2
  echo "   Add vpn.yml in private rednaw/secrets (Default token mirror + vpn_* for server vpn)." >&2
  return 1 2>/dev/null || exit 1
fi

__secrets=$(SOPS_AGE_KEY_FILE="${SOPS_KEY_FILE}" sops -d "${SECRETS_VPN}")

TF_VAR_hcloud_token=$(echo "${__secrets}" | yq -r '.hcloud_token // ""')
TF_VAR_ssh_keys=$(echo "${__secrets}" | yq '.ssh_keys // null' -o=json)
TF_VAR_vpn_allowed_ssh_ips=$(echo "${__secrets}" | yq '.vpn_allowed_ssh_ips // null' -o=json)

_missing=()
[ -n "${TF_VAR_hcloud_token}" ] && [ "${TF_VAR_hcloud_token}" != "null" ] || _missing+=("hcloud_token")
[ "${TF_VAR_ssh_keys}" != "null" ] && [ "${TF_VAR_ssh_keys}" != "[]" ] || _missing+=("ssh_keys")
[ "${TF_VAR_vpn_allowed_ssh_ips}" != "null" ] && [ "${TF_VAR_vpn_allowed_ssh_ips}" != "[]" ] || _missing+=("vpn_allowed_ssh_ips")
if [ "${#_missing[@]}" -gt 0 ]; then
  echo "❌ Missing from ${SECRETS_VPN}: ${_missing[*]}" >&2
  unset __secrets _missing
  return 1 2>/dev/null || exit 1
fi

export TF_VAR_hcloud_token
export TF_VAR_ssh_keys
export TF_VAR_vpn_allowed_ssh_ips

export HCLOUD_TOKEN="${TF_VAR_hcloud_token}"
unset HCLOUD_CONTEXT 2>/dev/null || true

unset __secrets _missing
