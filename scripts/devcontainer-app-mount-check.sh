#!/usr/bin/env bash
# Warn if the app deploy files are not mounted. Run ./scripts/setup-app-path.sh on the host.
# See docs/application-deployment.md#app-mount.
set -euo pipefail

APP_ROOT="/workspaces/iac/app"
REQUIRED=(iac.yml docker-compose.yml secrets.yml)
missing=()

for f in "${REQUIRED[@]}"; do
  [[ -f "$APP_ROOT/$f" ]] || missing+=("$f")
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo ""
  echo "⚠️  App deploy files not mounted at $APP_ROOT: ${missing[*]}"
  echo "   Run ./scripts/setup-app-path.sh /path/to/app on the host, then reopen the devcontainer."
  echo "   See docs/application-deployment.md"
  echo ""
fi
