#!/usr/bin/env bash
# Source this from the IaC repo root to populate TF_VAR_* for the platform
# Terraform root from app/.iac/iac.yml.
#
# Caller contract:
#   - cwd is the IaC repo root (paths are relative)
#   - SOPS_KEY_FILE is exported (path to age private key)
#
# Example:
#   export SOPS_KEY_FILE="$HOME/.config/sops/age/keys.txt"
#   . ./scripts/platform-tf-secrets.sh
#   terraform -chdir=terraform/platform plan
#
# This script is platform-specific. Future server purposes (vpn, honeypot)
# add their own scripts and pass them via the SECRETS_SCRIPT task variable.

: "${SOPS_KEY_FILE:?SOPS_KEY_FILE must be exported before sourcing this script}"

__secrets=$(SOPS_AGE_KEY_FILE="${SOPS_KEY_FILE}" sops -d app/.iac/iac.yml)

TF_VAR_hcloud_token=$(echo "${__secrets}" | yq -r '.hcloud_token')
TF_VAR_base_domain=$(echo "${__secrets}" | yq -r '.base_domain')
TF_VAR_ssh_keys=$(echo "${__secrets}" | yq '.ssh_keys' -o=json)
TF_VAR_allowed_ssh_ips=$(echo "${__secrets}" | yq '.allowed_ssh_ips' -o=json)
TF_VAR_server_type=$(echo "${__secrets}" | yq -r '.server_type // "cx23"')
TF_VAR_transip_account_name=$(echo "${__secrets}" | yq -r '.transip_account_name')
TF_VAR_transip_private_key=$(echo "${__secrets}" | yq -r '.transip_private_key')

export TF_VAR_hcloud_token
export TF_VAR_base_domain
export TF_VAR_ssh_keys
export TF_VAR_allowed_ssh_ips
export TF_VAR_server_type
export TF_VAR_transip_account_name
export TF_VAR_transip_private_key

unset __secrets
