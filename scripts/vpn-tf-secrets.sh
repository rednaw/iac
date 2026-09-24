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

_IAC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${SECRETS_DIR:-$(realpath -m "${_IAC_ROOT}/../secrets")}"
SECRETS_INFRA="${SECRETS_INFRA:-${SECRETS_DIR}/infra.yml}"
if [ ! -f "${SECRETS_INFRA}" ]; then
  echo "❌ Encrypted infra missing: ${SECRETS_INFRA}" >&2
  echo "   Clone private rednaw/secrets beside iac (../secrets)." >&2
  return 1 2>/dev/null || exit 1
fi

__secrets=$(SOPS_AGE_KEY_FILE="${SOPS_KEY_FILE}" sops -d "${SECRETS_INFRA}")

TF_VAR_hcloud_token=$(echo "${__secrets}" | yq -r '.hcloud_token')
TF_VAR_ssh_keys=$(echo "${__secrets}" | yq '.ssh_keys' -o=json)
TF_VAR_vpn_allowed_ssh_ips=$(echo "${__secrets}" | yq '.vpn_allowed_ssh_ips' -o=json)

export TF_VAR_hcloud_token
export TF_VAR_ssh_keys
export TF_VAR_vpn_allowed_ssh_ips

unset __secrets _IAC_ROOT
