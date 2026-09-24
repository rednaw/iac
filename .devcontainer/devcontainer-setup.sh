#!/usr/bin/env bash
# DevContainer setup script.
# Runs as postCreateCommand.
#
# Bootstrap mode: sibling ../secrets/infra.yml absent → tools available, secrets skipped.
# Operational mode: secrets sibling present → full setup, hard failure on any error.
set -euo pipefail

IAC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${SECRETS_DIR:-$(realpath -m "${IAC_ROOT}/../secrets")}"
INFRA_FILE="${SECRETS_DIR}/infra.yml"
SOPS_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
DOCKER_CONFIG="${HOME}/.docker/config.json"
HCLOUD_CONFIG_DIR="${HOME}/.config/hcloud"

########################################
# Trust mise tools
########################################

mise trust -a

########################################
# Sync workspace mise.toml pins into /opt/mise (root-owned installs)
########################################
#
# The dev image bakes tools from mise.toml at build time. If Renovate bumps the
# repo's mise.toml before a new image ships, mise resolves the workspace version
# and tries to lazy-install under /opt/mise/installs — which fails as vscode
# (permission denied). Installing once as root prevents that regression.
########################################

_sync_mise_tools() {
  if ! sudo -n true 2>/dev/null; then
    echo "WARN: passwordless sudo unavailable; if terraform/terraform fail, rebuild the dev image or run: sudo mise install" >&2
    return 0
  fi
  echo "Syncing mise tools to match workspace mise.toml (sudo mise install)..."
  sudo env MISE_DATA_DIR=/opt/mise MISE_GLOBAL_CONFIG_FILE=/opt/mise/mise.toml \
    PATH="/usr/local/bin:${PATH}" bash -lc 'cd /workspaces/iac && mise trust -a && mise install -y'
}

_sync_mise_tools

########################################
# Bootstrap mode
########################################

if [ ! -f "$INFRA_FILE" ]; then
  echo ""
  echo "Infrastructure not initialised — ${INFRA_FILE} missing."
  echo "  • Clone private rednaw/secrets beside iac (../secrets)"
  echo "  • Or first-time:                              run 'task secrets:init'"
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
# this is a non-platform fork (e.g. VPN-only) and registry auth is skipped.
if [ -n "$REG_USER" ] && [ -n "$REG_PASS" ]; then
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
# Always refresh — a stale line in bashrc/zshrc survives rebuilds when $HOME persists
# and otherwise leaves TF_TOKEN pointing at a revoked token ("No existing workspaces").
for profile in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
  if [ -f "$profile" ]; then
    grep -v 'TF_TOKEN_app_terraform_io=' "$profile" > "${profile}.tmp" && mv "${profile}.tmp" "$profile"
    printf '\nexport TF_TOKEN_app_terraform_io="%s"\n' "$TFC_TOKEN" >> "$profile"
  fi
done
echo "Terraform Cloud token configured."

########################################
# SSH config (Host platform → API IPv4)
########################################

cd /workspaces/iac || exit 1
bash .devcontainer/setup-remote-ssh.sh

########################################
# Docker context (local daemon only)
########################################

docker context create host --docker "host=unix:///var/run/docker.sock" 2>/dev/null || true
docker context use host
echo "Docker context: host"

########################################
# Cursor state
########################################

sudo chown -R vscode:vscode /home/vscode/.cursor 2>/dev/null || true
