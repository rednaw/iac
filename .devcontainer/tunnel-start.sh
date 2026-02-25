#!/usr/bin/env bash
# Auto-start tunnel when devcontainer starts/attaches.
# Runs in background for the lifetime of the devcontainer.
# Never fails the devcontainer: on tunnel failure we log and exit 0 so the window opens.
# Set AUTO_START_TUNNEL=prod to connect to prod instead of dev (default).
set -euo pipefail

# Determine workspace from environment variable or default to dev
WORKSPACE="${AUTO_START_TUNNEL:-dev}"

if [[ "$WORKSPACE" != "dev" ]] && [[ "$WORKSPACE" != "prod" ]]; then
    echo "⚠️  Invalid AUTO_START_TUNNEL value: $WORKSPACE (must be 'dev' or 'prod')"
    echo "   Defaulting to 'dev'"
    WORKSPACE="dev"
fi

echo "🚇 Starting tunnel to $WORKSPACE..."
cd /workspaces/iac || exit 0

LOG=/tmp/tunnel-start.log
RETRIES=3
INTERVAL=3

for i in $(seq 1 "$RETRIES"); do
    if task tunnel:start -- "$WORKSPACE" > "$LOG" 2>&1; then
        echo "✅ Tunnel to $WORKSPACE is running."
        echo ""
        echo "📊 Dashboards: http://localhost:8080/dashboard/ (Traefik), http://localhost:5080/ (OpenObserve)"
        echo "💡 Stop: task tunnel:stop -- $WORKSPACE"
        exit 0
    fi
    if [[ $i -lt $RETRIES ]]; then
        echo "   Attempt $i/$RETRIES failed, retrying in ${INTERVAL}s..."
        sleep "$INTERVAL"
    fi
done

echo "⚠️  Tunnel could not be started after $RETRIES attempts (server down or unreachable)."
echo "   Devcontainer is ready. To retry: task tunnel:start -- $WORKSPACE"
echo "   Details: $LOG"
cat "$LOG"
exit 0
