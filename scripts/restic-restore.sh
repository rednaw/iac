#!/usr/bin/env bash
# Run restore_from_backup.py on the platform server (SSH + prefect-worker).
#
# Requires BACKUP_APP_SLUG in the environment (deploy directory basename; same as
# basename of image_name in app/.iac/iac.yml — see ansible deploy_app resolve-image).
#
# Usage: BACKUP_APP_SLUG=… restic-restore.sh <dev|prod> [restore_from_backup.py args…]

set -euo pipefail

: "${BASE_DOMAIN:?BASE_DOMAIN must be set (use from devcontainer)}"
: "${BACKUP_APP_SLUG:?BACKUP_APP_SLUG must be set (e.g. by task backup:restore from mounted app/.iac/iac.yml)}"

WORKSPACE="${1:-}"
if [ -z "$WORKSPACE" ]; then
  echo "Usage: BACKUP_APP_SLUG=<slug> $0 <dev|prod> [snapshot] [--confirm|--postgres-only|...]"
  exit 1
fi
shift

case "$WORKSPACE" in
  dev)  HOST="dev.${BASE_DOMAIN}" ;;
  prod) HOST="prod.${BASE_DOMAIN}" ;;
  *)
    echo "Workspace must be dev or prod"
    exit 1
    ;;
esac

quoted=$(printf '%q ' "$BACKUP_APP_SLUG" "$@")
quoted=${quoted%% }

ssh -t "ubuntu@${HOST}" "docker run --rm -i \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/iac:/opt/iac \
  -w /opt/iac/prefect/flows/backup \
  prefect-worker \
  python3 restore_from_backup.py ${quoted}"
