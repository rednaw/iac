#!/usr/bin/env bash
# Warn if the app is not mounted at /workspaces/iac/app (APP_HOST_PATH not set or invalid).
# See docs/application-deployment.md#app-mount.
set -euo pipefail

APP_ROOT="/workspaces/iac/app"
IAC_DOCS="docs/application-deployment.md"

if [ ! -d "$APP_ROOT" ] || [ ! -f "$APP_ROOT/iac.yml" ]; then
  echo ""
  echo "⚠️  App not mounted or missing iac.yml at $APP_ROOT"
  echo "   Set APP_HOST_PATH in your local environment (e.g. .zshrc) and reopen the devcontainer."
  echo "   See $IAC_DOCS for details."
  echo ""
fi
