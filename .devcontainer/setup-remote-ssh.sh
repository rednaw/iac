#!/usr/bin/env bash
# Write dev and prod SSH host blocks to ~/.ssh/config.d/iac-admin (fully managed, overwritten each run).
# Add "Include config.d/iac-admin" to ~/.ssh/config to use them.
# Run from devcontainer setup, or manually: bash .devcontainer/setup-remote-ssh.sh
set -euo pipefail

CONFIGD=~/.ssh/config.d
FILE="$CONFIGD/iac-admin"
mkdir -p "$CONFIGD"

DEV_HOSTNAME=$(task hostkeys:hostname -- dev)
PROD_HOSTNAME=$(task hostkeys:hostname -- prod)

cat > "$FILE" <<EOF
# IaC admin access (dev and prod). Fully managed; overwritten each run.
# Port forwarding works automatically with Remote-SSH (VS Code/Cursor) via LocalForward

Host dev
  HostName $DEV_HOSTNAME
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  LocalForward 5080 localhost:5080
  LocalForward 8080 localhost:8080

Host prod
  HostName $PROD_HOSTNAME
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  LocalForward 5080 localhost:5080
  LocalForward 8080 localhost:8080

# Same host as dev/prod, User observer, no port forwards (avoids conflict when tunnel is up)
Host dev-observer
  HostName $DEV_HOSTNAME
  User observer
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new

Host prod-observer
  HostName $PROD_HOSTNAME
  User observer
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
EOF

chmod 600 "$FILE"
echo "Wrote $FILE (dev -> $DEV_HOSTNAME, prod -> $PROD_HOSTNAME)."
echo "Port forwarding: OpenObserve 5080, Traefik dashboard 8080."

# Auto-add Include line to ~/.ssh/config (idempotent, create if missing, skip if already included)
SSH_CONFIG=~/.ssh/config
if [ -f "$SSH_CONFIG" ]; then
  # Skip if already included (exact match or wildcard pattern)
  if grep -qE '(Include|include).*config\.d/iac-admin' "$SSH_CONFIG" 2>/dev/null || \
     grep -qE '(Include|include).*config\.d/\*' "$SSH_CONFIG" 2>/dev/null; then
    echo "SSH config already includes config.d/iac-admin (skipping)."
  else
    # Append Include line
    echo "" >> "$SSH_CONFIG"
    echo "Include config.d/iac-admin" >> "$SSH_CONFIG"
    echo "Added 'Include config.d/iac-admin' to ~/.ssh/config"
  fi
else
  # Create config file with Include line
  mkdir -p ~/.ssh
  echo "Include config.d/iac-admin" > "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
  echo "Created ~/.ssh/config with 'Include config.d/iac-admin'"
fi
