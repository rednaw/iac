#!/usr/bin/env bash
# Source this from the IaC repo root to load the dev vpn box's Hetzner token
# from the private secrets sibling (../secrets/vpn.yml) only.
#
# Exports HCLOUD_TOKEN (overwriting any ambient token in the shell) for the
# hcloud ops scripts. Provision (Ansible) reads vpn.yml itself.
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

__token=$(SOPS_AGE_KEY_FILE="${SOPS_KEY_FILE}" sops -d "${SECRETS_VPN}" | yq -r '.hcloud_token // ""')

if [ -z "${__token}" ] || [ "${__token}" = "null" ]; then
  echo "❌ Missing from ${SECRETS_VPN}: hcloud_token" >&2
  unset __token
  return 1 2>/dev/null || exit 1
fi

export HCLOUD_TOKEN="${__token}"
unset HCLOUD_CONTEXT 2>/dev/null || true

unset __token
