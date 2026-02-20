#!/usr/bin/env bash
# Write dev and prod SSH host blocks to ~/.ssh/config.d/iac-admin (fully managed, overwritten each run).
# Add "Include config.d/iac-admin" to ~/.ssh/config to use them.
set -euo pipefail

CONFIGD=~/.ssh/config.d
FILE="$CONFIGD/iac-admin"
mkdir -p "$CONFIGD"

DEV_HOSTNAME=$(task hostkeys:hostname -- dev)
PROD_HOSTNAME=$(task hostkeys:hostname -- prod)

cat > "$FILE" <<EOF
# IaC admin access (dev and prod). Fully managed by: task server:setup-remote-cursor

Host dev
  HostName $DEV_HOSTNAME
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  LocalForward 5080 localhost:5080
  LocalForward 5000 localhost:5000
  LocalForward 8080 localhost:8080

Host prod
  HostName $PROD_HOSTNAME
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  LocalForward 5080 localhost:5080
  LocalForward 5000 localhost:5000
  LocalForward 8080 localhost:8080
EOF

chmod 600 "$FILE"
echo "Wrote $FILE (dev -> $DEV_HOSTNAME, prod -> $PROD_HOSTNAME)."
echo "Port forwarding: OpenObserve 5080, Registry 5000, Traefik dashboard 8080."
if ! grep -q 'Include config.d/iac-admin' ~/.ssh/config 2>/dev/null; then
  echo "Add this line to ~/.ssh/config to use these hosts:"
  echo "  Include config.d/iac-admin"
fi
