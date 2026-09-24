#!/usr/bin/env bash
# Write Host platform → API IPv4 to ~/.ssh/config.d/iac-admin (fully managed, overwritten each run).
# Add "Include config.d/iac-admin" to ~/.ssh/config to use it.
# Run from devcontainer setup, or manually: bash .devcontainer/setup-remote-ssh.sh
set -euo pipefail

CONFIGD=~/.ssh/config.d
FILE="$CONFIGD/iac-admin"
mkdir -p "$CONFIGD"

PLATFORM_IP=$(task hostkeys:ip -- platform)

cat > "$FILE" <<EOF
# IaC admin access (platform). Fully managed; overwritten each run.
# Dashboards: task tunnel:start + portal.html (no LocalForward here).

Host platform
  HostName $PLATFORM_IP
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
EOF

chmod 600 "$FILE"
echo "Wrote $FILE (platform -> $PLATFORM_IP)."

# Auto-add Include line to ~/.ssh/config (idempotent, create if missing, skip if already included)
SSH_CONFIG=~/.ssh/config
if [ -f "$SSH_CONFIG" ]; then
  if grep -qE '(Include|include).*config\.d/iac-admin' "$SSH_CONFIG" 2>/dev/null || \
     grep -qE '(Include|include).*config\.d/\*' "$SSH_CONFIG" 2>/dev/null; then
    echo "SSH config already includes config.d/iac-admin (skipping)."
  else
    echo "" >> "$SSH_CONFIG"
    echo "Include config.d/iac-admin" >> "$SSH_CONFIG"
    echo "Added 'Include config.d/iac-admin' to ~/.ssh/config"
  fi
else
  mkdir -p ~/.ssh
  echo "Include config.d/iac-admin" > "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
  echo "Created ~/.ssh/config with 'Include config.d/iac-admin'"
fi
