#!/usr/bin/env bash
# Source this from the IaC repo root to load the legacy gate box's Hetzner token
# from the private secrets sibling (../secrets/gate.yml) only.
#
# Exports HCLOUD_TOKEN (overwriting any ambient Default/Rednaw token in the
# shell) so hcloud/hostkeys hit project Gate. Never reads infra.yml.

: "${SOPS_KEY_FILE:?SOPS_KEY_FILE must be exported before sourcing this script}"

if [ -z "${SECRETS_DIR:-}" ]; then
  _here="${BASH_SOURCE[0]-}"
  [ -n "${_here}" ] || _here="$0"
  _IAC_ROOT="$(cd "$(dirname "${_here}")/.." && pwd)"
  SECRETS_DIR="$(realpath -m "${_IAC_ROOT}/../secrets")"
  unset _here _IAC_ROOT
fi
SECRETS_GATE="${SECRETS_GATE:-${SECRETS_DIR}/gate.yml}"
if [ ! -f "${SECRETS_GATE}" ]; then
  echo "❌ Encrypted gate secrets missing: ${SECRETS_GATE}" >&2
  echo "   Add gate.yml in private rednaw/secrets (project-Gate token + Fresh vpn_*)." >&2
  return 1 2>/dev/null || exit 1
fi

__token=$(SOPS_AGE_KEY_FILE="${SOPS_KEY_FILE}" sops -d "${SECRETS_GATE}" | yq -r '.hcloud_token // ""')

if [ -z "${__token}" ] || [ "${__token}" = "null" ]; then
  echo "❌ Missing from ${SECRETS_GATE}: hcloud_token" >&2
  unset __token
  return 1 2>/dev/null || exit 1
fi

export HCLOUD_TOKEN="${__token}"
unset HCLOUD_CONTEXT 2>/dev/null || true

unset __token
