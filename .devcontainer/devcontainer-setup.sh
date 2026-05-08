#!/usr/bin/env bash
# DevContainer setup script.
# Runs as postCreateCommand.
#
# Bootstrap mode: secrets/infra.yml absent → tools available, secrets skipped.
# Operational mode: secrets/infra.yml present → full setup, hard failure on any error.
set -euo pipefail

INFRA_FILE="secrets/infra.yml"
SOPS_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
DOCKER_CONFIG="${HOME}/.docker/config.json"
HCLOUD_CONFIG_DIR="${HOME}/.config/hcloud"

########################################
# Trust mise tools
########################################

mise trust -a

########################################
# Bootstrap mode
########################################

if [ ! -f "$INFRA_FILE" ]; then
  echo ""
  echo "Infrastructure not initialised — secrets/infra.yml missing."
  echo "  • New fork:                              run 'task secrets:init'"
  echo "  • Existing user (had app/.iac/iac.yml):  run 'task secrets:migrate-from-app'"
  echo ""
  sudo chown -R vscode:vscode /home/vscode/.cursor 2>/dev/null || true
  exit 0
fi

########################################
# Operational mode — hard failure from here
########################################

if [ ! -f "$SOPS_KEY_FILE" ]; then
  echo "ERROR: SOPS key not found at $SOPS_KEY_FILE. Mount ~/.config/sops or run task secrets:keygen." >&2
  exit 1
fi

DECRYPTED=$(SOPS_AGE_KEY_FILE="$SOPS_KEY_FILE" sops -d "$INFRA_FILE") || {
  echo "ERROR: Failed to decrypt $INFRA_FILE. Check your SOPS key." >&2
  exit 1
}

BASE_DOMAIN=$(echo "$DECRYPTED" | yq -r '.base_domain // ""')
[ -n "$BASE_DOMAIN" ] || { echo "ERROR: base_domain missing from $INFRA_FILE." >&2; exit 1; }

REGISTRY="registry.${BASE_DOMAIN}"
export BASE_DOMAIN REGISTRY

for profile in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
  [ -f "$profile" ] && ! grep -q "BASE_DOMAIN=" "$profile" 2>/dev/null && \
    printf '\nexport BASE_DOMAIN="%s"\nexport REGISTRY="%s"\n' "$BASE_DOMAIN" "$REGISTRY" >> "$profile"
done

########################################
# Docker registry (platform-only — soft-skip when not configured)
########################################

REG_USER=$(echo "$DECRYPTED" | yq -r '.registry_username // ""')
REG_PASS=$(echo "$DECRYPTED" | yq -r '.registry_password // ""')

# When both registry creds are present the platform stack is in use; otherwise
# this is a non-platform fork (e.g. VPN-only) and the platform-specific setup
# steps below are skipped.
PLATFORM_ENABLED=0
if [ -n "$REG_USER" ] && [ -n "$REG_PASS" ]; then
  PLATFORM_ENABLED=1

  mkdir -p "$(dirname "$DOCKER_CONFIG")"
  AUTH=$(printf '%s' "$REG_USER:$REG_PASS" | base64 | tr -d '\n')

  if [ -f "$DOCKER_CONFIG" ]; then
    jq --arg registry "$REGISTRY" --arg auth "$AUTH" \
      '.auths[$registry] = {auth: $auth}' \
      "$DOCKER_CONFIG" > "${DOCKER_CONFIG}.tmp" && mv "${DOCKER_CONFIG}.tmp" "$DOCKER_CONFIG"
  else
    jq -n --arg registry "$REGISTRY" --arg auth "$AUTH" \
      '{auths: {($registry): {auth: $auth}}}' > "$DOCKER_CONFIG"
  fi
  chmod 600 "$DOCKER_CONFIG"
  echo "Registry auth configured for $REGISTRY."
else
  echo "Skipping registry auth (registry_username/registry_password not set in $INFRA_FILE — non-platform fork)."
fi

########################################
# hcloud
########################################

HCLOUD_TOKEN=$(echo "$DECRYPTED" | yq -r '.hcloud_token // ""')
[ -n "$HCLOUD_TOKEN" ] || { echo "ERROR: hcloud_token missing from $INFRA_FILE." >&2; exit 1; }

mkdir -p "$HCLOUD_CONFIG_DIR"
cat > "$HCLOUD_CONFIG_DIR/cli.toml" <<EOF
active_context = "default"

[[contexts]]
  name = "default"
  token = "$HCLOUD_TOKEN"
EOF
chmod 600 "$HCLOUD_CONFIG_DIR/cli.toml"
echo "hcloud CLI configured (context \"default\")."

########################################
# Terraform Cloud
########################################

TFC_TOKEN=$(echo "$DECRYPTED" | yq -r '.terraform_cloud_token // ""')
[ -n "$TFC_TOKEN" ] || { echo "ERROR: terraform_cloud_token missing from $INFRA_FILE." >&2; exit 1; }

export TF_TOKEN_app_terraform_io="$TFC_TOKEN"
for profile in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
  [ -f "$profile" ] && ! grep -q "TF_TOKEN_app_terraform_io" "$profile" 2>/dev/null && \
    printf '\nexport TF_TOKEN_app_terraform_io="%s"\n' "$TFC_TOKEN" >> "$profile"
done
echo "Terraform Cloud token configured."

########################################
# SSH config for Remote-SSH
########################################

cd /workspaces/iac || exit 1
bash .devcontainer/setup-remote-ssh.sh

########################################
# Docker contexts (host always; dev/prod only when platform stack is in use)
########################################

# Named contexts: host = daemon running this container, dev/prod = platform servers over SSH.
# dev/prod assume hostnames dev.<base_domain> / prod.<base_domain>, which is a
# platform convention. Skipped when the fork doesn't use the platform stack.
docker context create host --docker "host=unix:///var/run/docker.sock" 2>/dev/null || true

if [ "$PLATFORM_ENABLED" = 1 ]; then
  DEV_HOST="dev.${BASE_DOMAIN}"
  PROD_HOST="prod.${BASE_DOMAIN}"
  docker context create dev --docker "host=ssh://ubuntu@${DEV_HOST}" 2>/dev/null || true
  docker context create prod --docker "host=ssh://ubuntu@${PROD_HOST}" 2>/dev/null || true
  docker context use host
  echo "Docker contexts: host (default) | dev | prod — docker context use <name>"
else
  docker context use host
  echo "Docker context: host (only — non-platform fork has no dev/prod servers)."
fi

########################################
# Cursor state
########################################

sudo chown -R vscode:vscode /home/vscode/.cursor 2>/dev/null || true
