#!/usr/bin/env bash
# Source this from the IaC repo root to populate TF_VAR_* for the vpn
# Terraform root from the private secrets sibling (../secrets/infra.yml).
#
# Caller contract:
#   - cwd is the IaC repo root (or SECRETS_DIR is exported)
#   - SOPS_KEY_FILE is exported (path to age private key)
#   - SECRETS_DIR defaults to realpath of ../secrets beside this repo
#
# Same hcloud_token and ssh_keys as platform (one Hetzner account); the SSH
# allowlist is the VPN's own (home only — never platform IPs, never the world).

: "${SOPS_KEY_FILE:?SOPS_KEY_FILE must be exported before sourcing this script}"

# Prefer caller-exported SECRETS_DIR (Task always sets it). Avoid BASH_SOURCE under
# `set -u` when this file is sourced from a non-bash or odd context.
if [ -z "${SECRETS_DIR:-}" ]; then
  _here="${BASH_SOURCE[0]-}"
  [ -n "${_here}" ] || _here="$0"
  _IAC_ROOT="$(cd "$(dirname "${_here}")/.." && pwd)"
  SECRETS_DIR="$(realpath -m "${_IAC_ROOT}/../secrets")"
  unset _here _IAC_ROOT
fi
SECRETS_INFRA="${SECRETS_INFRA:-${SECRETS_DIR}/infra.yml}"
if [ ! -f "${SECRETS_INFRA}" ]; then
  echo "❌ Encrypted infra missing: ${SECRETS_INFRA}" >&2
  echo "   Clone private rednaw/secrets beside iac (../secrets)." >&2
  return 1 2>/dev/null || exit 1
fi

__secrets=$(SOPS_AGE_KEY_FILE="${SOPS_KEY_FILE}" sops -d "${SECRETS_INFRA}")

TF_VAR_hcloud_token=$(echo "${__secrets}" | yq -r '.hcloud_token // ""')
TF_VAR_ssh_keys=$(echo "${__secrets}" | yq '.ssh_keys // null' -o=json)
TF_VAR_vpn_allowed_ssh_ips=$(echo "${__secrets}" | yq '.vpn_allowed_ssh_ips // null' -o=json)

_missing=()
[ -n "${TF_VAR_hcloud_token}" ] && [ "${TF_VAR_hcloud_token}" != "null" ] || _missing+=("hcloud_token")
[ "${TF_VAR_ssh_keys}" != "null" ] && [ "${TF_VAR_ssh_keys}" != "[]" ] || _missing+=("ssh_keys")
[ "${TF_VAR_vpn_allowed_ssh_ips}" != "null" ] && [ "${TF_VAR_vpn_allowed_ssh_ips}" != "[]" ] || _missing+=("vpn_allowed_ssh_ips")
if [ "${#_missing[@]}" -gt 0 ]; then
  echo "❌ Missing from ${SECRETS_INFRA} (manual §2.1): ${_missing[*]}" >&2
  unset __secrets _missing
  return 1 2>/dev/null || exit 1
fi

export TF_VAR_hcloud_token
export TF_VAR_ssh_keys
export TF_VAR_vpn_allowed_ssh_ips

unset __secrets _missing
