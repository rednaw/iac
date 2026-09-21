#!/usr/bin/env bash
# Source this from the IaC repo root to populate TF_VAR_* for the vpn
# Terraform root from secrets/infra.yml.
#
# Caller contract:
#   - cwd is the IaC repo root (paths are relative)
#   - SOPS_KEY_FILE is exported (path to age private key)
#
# Same hcloud_token and ssh_keys as platform (one Hetzner account); the SSH
# allowlist is the VPN's own (home only — never platform IPs, never the world).

: "${SOPS_KEY_FILE:?SOPS_KEY_FILE must be exported before sourcing this script}"

__secrets=$(SOPS_AGE_KEY_FILE="${SOPS_KEY_FILE}" sops -d secrets/infra.yml)

TF_VAR_hcloud_token=$(echo "${__secrets}" | yq -r '.hcloud_token')
TF_VAR_ssh_keys=$(echo "${__secrets}" | yq '.ssh_keys' -o=json)
TF_VAR_vpn_allowed_ssh_ips=$(echo "${__secrets}" | yq '.vpn_allowed_ssh_ips' -o=json)

export TF_VAR_hcloud_token
export TF_VAR_ssh_keys
export TF_VAR_vpn_allowed_ssh_ips

unset __secrets
