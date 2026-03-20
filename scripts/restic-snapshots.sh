#!/usr/bin/env bash
# List Restic snapshots for an app's local repo on the platform server (SSH + prefect-worker).
#
# Requires BACKUP_APP_SLUG (deploy basename = basename of image_name in app/.iac/iac.yml).
#
# Usage: BACKUP_APP_SLUG=… restic-snapshots.sh <dev|prod>

set -euo pipefail

: "${BASE_DOMAIN:?BASE_DOMAIN must be set (use from devcontainer)}"
: "${BACKUP_APP_SLUG:?BACKUP_APP_SLUG must be set (e.g. by task backup:snapshots from mounted app/.iac/iac.yml)}"

WORKSPACE="${1:-}"
if [ -z "$WORKSPACE" ]; then
  echo "Usage: BACKUP_APP_SLUG=<slug> $0 <dev|prod>"
  exit 1
fi

case "$WORKSPACE" in
  dev)  HOST="dev.${BASE_DOMAIN}" ;;
  prod) HOST="prod.${BASE_DOMAIN}" ;;
  *)
    echo "Workspace must be dev or prod"
    exit 1
    ;;
esac

# :ro repo cannot hold lock files; --no-lock is read-only safe for snapshots.
ssh "ubuntu@${HOST}" "docker run --rm \
  -v /opt/iac/prefect/backups/${BACKUP_APP_SLUG}:/repo:ro \
  -e RESTIC_REPOSITORY=/repo \
  -e RESTIC_PASSWORD=local \
  prefect-worker \
  restic --no-lock snapshots"
