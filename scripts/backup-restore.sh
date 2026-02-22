#!/usr/bin/env bash
# Restore Hetzner server from a backup image.
# Usage: backup-restore.sh <workspace> <image-id>
# Example: backup-restore.sh dev 360435573
# Get image-id from: task backup:list -- dev

set -e

ARGS="$*"
set -- $ARGS
WORKSPACE="${1:-}"
IMAGE_ID="${2:-}"
SERVER_NAME="platform-${WORKSPACE}"

if [ "$#" -lt 2 ] || [ -z "$WORKSPACE" ] || [ -z "$IMAGE_ID" ]; then
  echo "Usage: task backup:restore -- <dev|prod> <image-id> (get image-id from backup:list)"
  exit 1
fi

if [ "$WORKSPACE" != "dev" ] && [ "$WORKSPACE" != "prod" ]; then
  echo "Invalid workspace. Use: dev or prod"
  exit 1
fi

echo "⚠️  This will REPLACE the disk of $SERVER_NAME with backup image $IMAGE_ID. All current data on the server will be lost."
echo ""
read -p "Type 'yes' to continue: " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }

hcloud server rebuild "$SERVER_NAME" --image "$IMAGE_ID"
