#!/usr/bin/env bash
# Source this from the IaC repo root to load the dev vpn box's Hetzner inputs
# from the private secrets sibling (../secrets/vpn.yml) only.
#
# Exports HCLOUD_TOKEN (overwriting any ambient token in the shell) plus
# BOX_SSH_KEYS_JSON for scripts/box-provision.sh.
# Never reads infra.yml. No standing SSH allowlist — use task vpn:ssh:allow.

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

__token=$(echo "${__secrets}" | yq -r '.hcloud_token // ""')
BOX_SSH_KEYS_JSON=$(echo "${__secrets}" | yq '.ssh_keys // null' -o=json -I=0)

_missing=()
[ -n "${__token}" ] && [ "${__token}" != "null" ] || _missing+=("hcloud_token")
[ "${BOX_SSH_KEYS_JSON}" != "null" ] && [ "${BOX_SSH_KEYS_JSON}" != "[]" ] || _missing+=("ssh_keys")
if [ "${#_missing[@]}" -gt 0 ]; then
  echo "❌ Missing from ${SECRETS_VPN}: ${_missing[*]}" >&2
  unset __secrets __token _missing
  return 1 2>/dev/null || exit 1
fi

export HCLOUD_TOKEN="${__token}"
export BOX_SSH_KEYS_JSON
unset HCLOUD_CONTEXT 2>/dev/null || true

unset __secrets __token _missing
