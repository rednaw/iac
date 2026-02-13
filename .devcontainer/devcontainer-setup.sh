#!/usr/bin/env bash
# DevContainer setup script:
# - Trust mise tools (user-specific, must run as vscode user)
# - Configure credentials from SOPS (Docker registry, hcloud, Terraform Cloud)
# Requires SOPS key and secrets/infrastructure-secrets.yml in repo.
set -euo pipefail

########################################
# Trust mise tools (user-specific)
########################################

mise trust -a

########################################
# Decrypt secrets once
########################################

REGISTRY="${REGISTRY:-registry.rednaw.nl}"
DOCKER_CONFIG="${HOME}/.docker/config.json"
HCLOUD_CONFIG_DIR="${HOME}/.config/hcloud"
HCLOUD_CONFIG_FILE="${HCLOUD_CONFIG_DIR}/cli.toml"
SOPS_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
SECRETS_FILE="${1:-secrets/infrastructure-secrets.yml}"

DECRYPTED=$(SOPS_AGE_KEY_FILE="$SOPS_KEY_FILE" sops -d "$SECRETS_FILE")

########################################
# Docker Registry (~/.docker/config.json)
########################################

mkdir -p "$(dirname "$DOCKER_CONFIG")"

REG_USER=$(echo "$DECRYPTED" | yq -r '.registry_username // ""')
REG_PASS=$(echo "$DECRYPTED" | yq -r '.registry_password // ""')

if [ -n "$REG_USER" ] && [ -n "$REG_PASS" ]; then
  AUTH=$(printf '%s' "$REG_USER:$REG_PASS" | base64 | tr -d '\n')

  if [ -f "$DOCKER_CONFIG" ]; then
    EXISTING_AUTH=$(jq -r --arg registry "$REGISTRY" '.auths[$registry].auth // empty' "$DOCKER_CONFIG" 2>/dev/null || echo "")
    if [ "$EXISTING_AUTH" = "$AUTH" ]; then
      echo "Registry auth for $REGISTRY already configured in $DOCKER_CONFIG (skipping)."
    else
      jq --arg registry "$REGISTRY" --arg auth "$AUTH" \
        '.auths[$registry] = {auth: $auth}' \
        "$DOCKER_CONFIG" > "${DOCKER_CONFIG}.tmp" && mv "${DOCKER_CONFIG}.tmp" "$DOCKER_CONFIG"
      echo "Registry auth updated for $REGISTRY in $DOCKER_CONFIG (merged with existing config)."
    fi
  else
    jq -n --arg registry "$REGISTRY" --arg auth "$AUTH" \
      '{auths: {($registry): {auth: $auth}}}' > "$DOCKER_CONFIG"
    echo "Registry auth configured for $REGISTRY in $DOCKER_CONFIG (new config created)."
  fi

  chmod 600 "$DOCKER_CONFIG"
else
  echo "Registry credentials (registry_username/registry_password) not found in $SECRETS_FILE, skipping registry auth."
fi

########################################
# hcloud (~/.config/hcloud/cli.toml)
########################################

HCLOUD_TOKEN=$(echo "$DECRYPTED" | yq -r '.hcloud_token // ""')

if [ -n "$HCLOUD_TOKEN" ]; then
  mkdir -p "$HCLOUD_CONFIG_DIR"

  cat > "$HCLOUD_CONFIG_FILE" <<EOF
active_context = "default"

[[contexts]]
  name = "default"
  token = "$HCLOUD_TOKEN"
EOF

  chmod 600 "$HCLOUD_CONFIG_FILE"
  echo "hcloud CLI config written to $HCLOUD_CONFIG_FILE (context \"default\")."
else
  echo "hcloud_token not found in $SECRETS_FILE, skipping hcloud CLI config."
fi

########################################
# Terraform Cloud (TF_TOKEN_app_terraform_io env var)
# Terraform Cloud supports environment variable authentication:
# https://developer.hashicorp.com/terraform/cloud-docs/workspaces/remote-state#environment-variable-credentials
########################################

TFC_TOKEN=$(echo "$DECRYPTED" | yq -r '.terraform_cloud_token // ""')

if [ -n "$TFC_TOKEN" ]; then
  export TF_TOKEN_app_terraform_io="$TFC_TOKEN"
  
  # Persist to shell profiles if they exist
  for profile in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    [ -f "$profile" ] && ! grep -q "TF_TOKEN_app_terraform_io" "$profile" 2>/dev/null && \
      echo "export TF_TOKEN_app_terraform_io=\"$TFC_TOKEN\"" >> "$profile"
  done
  
  echo "Terraform Cloud token configured (TF_TOKEN_app_terraform_io)."
else
  echo "terraform_cloud_token not found in $SECRETS_FILE, skipping Terraform Cloud credentials."
fi

