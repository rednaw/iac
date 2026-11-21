#!/usr/bin/env bash
# Source this from the IaC repo root to load the platform box's Hetzner token
# from the private secrets sibling (../secrets/infra.yml).
#
# Exports HCLOUD_TOKEN (overwriting any ambient token in the shell) for the
# hcloud ops scripts. Provision (Ansible) reads infra.yml itself.
# No standing SSH allowlist — use task platform:ssh:allow.

: "${SOPS_KEY_FILE:?SOPS_KEY_FILE must be exported before sourcing this script}"

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

__token=$(SOPS_AGE_KEY_FILE="${SOPS_KEY_FILE}" sops -d "${SECRETS_INFRA}" | yq -r '.hcloud_token // ""')

if [ -z "${__token}" ] || [ "${__token}" = "null" ]; then
  echo "❌ Missing from ${SECRETS_INFRA}: hcloud_token" >&2
  unset __token
  return 1 2>/dev/null || exit 1
fi

export HCLOUD_TOKEN="${__token}"
unset HCLOUD_CONTEXT 2>/dev/null || true

unset __token
