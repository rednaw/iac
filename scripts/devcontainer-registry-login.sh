#!/usr/bin/env bash
# Configure registry auth from SOPS so docker/crane/trivy work without manual docker login.
# Merges auth into existing ~/.docker/config.json without overwriting other registries.
# Requires SOPS key and secrets/infrastructure-secrets.yml in repo.
set -euo pipefail

REGISTRY="${REGISTRY:-registry.rednaw.nl}"
DOCKER_CONFIG="${HOME}/.docker/config.json"
SOPS_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
SECRETS_FILE="${1:-secrets/infrastructure-secrets.yml}"

# Check required tools
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
fi

# Ensure .docker directory exists
mkdir -p "$(dirname "$DOCKER_CONFIG")"

# Decrypt secrets and extract credentials
DECRYPTED=$(SOPS_AGE_KEY_FILE="$SOPS_KEY_FILE" sops -d "$SECRETS_FILE")
REG_USER=$(echo "$DECRYPTED" | yq -r '.registry_username')
REG_PASS=$(echo "$DECRYPTED" | yq -r '.registry_password')

# Generate base64 auth string
AUTH=$(printf '%s' "$REG_USER:$REG_PASS" | base64 | tr -d '\n')

# Check if auth already exists and matches
if [ -f "$DOCKER_CONFIG" ]; then
  EXISTING_AUTH=$(jq -r --arg registry "$REGISTRY" '.auths[$registry].auth // empty' "$DOCKER_CONFIG" 2>/dev/null || echo "")
  if [ "$EXISTING_AUTH" = "$AUTH" ]; then
    echo "Registry auth for $REGISTRY already configured in $DOCKER_CONFIG (skipping)."
    exit 0
  fi
  # Auth exists but is different, or registry doesn't exist - update it
  jq --arg registry "$REGISTRY" --arg auth "$AUTH" \
    '.auths[$registry] = {auth: $auth}' \
    "$DOCKER_CONFIG" > "${DOCKER_CONFIG}.tmp" && mv "${DOCKER_CONFIG}.tmp" "$DOCKER_CONFIG"
  echo "Registry auth updated for $REGISTRY in $DOCKER_CONFIG (merged with existing config)."
else
  # Create new config.json with just this registry
  jq -n --arg registry "$REGISTRY" --arg auth "$AUTH" \
    '{auths: {($registry): {auth: $auth}}}' > "$DOCKER_CONFIG"
  echo "Registry auth configured for $REGISTRY in $DOCKER_CONFIG (new config created)."
fi

# Set appropriate permissions (ignore errors if file is owned by different user)
chmod 600 "$DOCKER_CONFIG" 2>/dev/null || true
