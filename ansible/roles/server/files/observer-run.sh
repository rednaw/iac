#!/usr/bin/env bash
# observer-run: run a command as root in a read-only environment (observer mode).
# Uses bubblewrap (bwrap) and an allowlist. See docs/cursor-agent-observer.md.

set -euo pipefail

ALLOWLIST_FILE="${OBSERVER_ALLOWLIST_FILE:-/etc/observer-allowed-commands}"

# Must run as root (sudo observer-run)
if [ "$(id -u)" -ne 0 ]; then
  echo "observer-run: must be run as root (use: sudo observer-run ...)" >&2
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "observer-run: no command given" >&2
  exit 1
fi

# If command was passed as one quoted string (e.g. "docker ps"), split into words
if [ $# -eq 1 ] && [[ "$1" == *" "* ]]; then
  set -- $1
fi

# Load allowlist: strip comments and blank lines
allowed_list=""
if [ -r "$ALLOWLIST_FILE" ]; then
  allowed_list=$(grep -v '^[[:space:]]*#' "$ALLOWLIST_FILE" | grep -v '^[[:space:]]*$' | sed 's/[[:space:]].*//' | tr '\n' ' ')
fi

is_allowed() {
  local key="$1"
  [[ " ${allowed_list} " == *" ${key} "* ]]
}

# Build allowlist key from argv
cmd="$1"
cmd_basename="$(basename "$cmd")"
sub="${2:-}"
sub2="${3:-}"

case "$cmd_basename" in
  docker)
    if [[ "$sub" == "system" || "$sub" == "volume" || "$sub" == "image" || "$sub" == "container" ]]; then
      key="docker:${sub}:${sub2}"
    else
      key="docker:${sub}"
    fi
    ;;
  systemctl)
    key="systemctl:${sub}"
    ;;
  *)
    key="$cmd_basename"
    ;;
esac

if ! is_allowed "$key"; then
  echo "observer-run: not allowed: $* (allowlist: $ALLOWLIST_FILE)" >&2
  exit 1
fi

if ! command -v bwrap >/dev/null 2>&1; then
  echo "observer-run: bwrap (bubblewrap) is required but not installed. Install the bubblewrap package." >&2
  exit 1
fi

exec bwrap \
  --ro-bind / / \
  --bind /home/observer /home/observer \
  --bind /tmp /tmp \
  --bind /home/ubuntu /home/ubuntu \
  --ro-bind /sys /sys \
  --dev /dev \
  --proc /proc \
  -- "$@"
