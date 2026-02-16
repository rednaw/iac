#!/usr/bin/env bash
# Set which app the IAC devcontainer mounts at /workspaces/iac/app.
# Writes export APP_HOST_PATH=... to your shell profile. Run from the host.
# See docs/application-deployment.md.
set -euo pipefail

MARKER="# IAC devcontainer: app path (setup-app-path.sh)"
REQUIRED_FILES=(iac.yml docker-compose.yml .env .sops.yaml)

running_in_devcontainer() {
  [[ -f /.dockerenv ]] || [[ -n "${DEVCONTAINER:-}" ]]
}

usage() {
  echo "Usage: $0 [PATH_TO_APP]"
  echo ""
  echo "  PATH_TO_APP  Absolute or relative path to your app repo."
  echo "               Must contain iac.yml, docker-compose.yml, .env, .sops.yaml."
  echo "               If omitted, you will be prompted."
  echo ""
  echo "Sets which app is mounted in the IAC devcontainer. Run again with a different path"
  echo "whenever you want to work on another app. See docs/application-deployment.md."
}

resolve_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd)
  else
    echo "$path"
  fi
}

validate_app() {
  local dir="$1"
  local missing=()
  for f in "${REQUIRED_FILES[@]}"; do
    [[ -f "$dir/$f" ]] || missing+=("$f")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Missing required files in $dir:"
    printf '   - %s\n' "${missing[@]}"
    echo ""
    echo "Each app must have iac.yml, docker-compose.yml, .env, and .sops.yaml."
    echo ".env can be minimal (e.g. empty or a single comment) if the app has no secrets."
    exit 1
  fi
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

update_profile() {
  local profile="$1"
  local app_path="$2"

  # Remove old block if present
  if [[ -f "$profile" ]] && grep -q "$MARKER" "$profile" 2>/dev/null; then
    awk -v marker="$MARKER" '
      $0 == marker { skip=1; next }
      skip && /^export APP_HOST_PATH=/ { skip=0; next }
      { print }
    ' "$profile" > "$profile.tmp" && mv "$profile.tmp" "$profile"
  fi

  # Append new block
  mkdir -p "$(dirname "$profile")"
  printf '\n%s\nexport APP_HOST_PATH="%s"\n' "$MARKER" "$app_path" >> "$profile"
}

main() {
  if running_in_devcontainer; then
    echo "This script must be run on the host, not inside the devcontainer."
    echo "Open a terminal on your Mac/Linux (outside Cursor) and run: $0 [PATH_TO_APP]"
    exit 1
  fi

  local path
  if [[ $# -gt 0 ]]; then
    if [[ "$1" = -h || "$1" = --help ]]; then
      usage
      exit 0
    fi
    path=$(resolve_path "$1")
  else
    echo "Path to your app repo (must contain iac.yml, docker-compose.yml, .env, .sops.yaml):"
    read -r path
    path=$(resolve_path "$path")
  fi

  validate_app "$path"

  local os
  os=$(detect_os)
  case "$os" in
    macos)
      update_profile "$HOME/.zprofile" "$path"
      launchctl setenv APP_HOST_PATH "$path"
      echo "Updated ~/.zprofile. Current session updated (launchctl). Reopen the IAC devcontainer to see the app."
      ;;
    linux)
      update_profile "$HOME/.profile" "$path"
      echo "Updated ~/.profile. Log out and back in (or run: source ~/.profile), then Reopen in Container."
      ;;
    *)
      echo "Unsupported OS. Add to your profile: export APP_HOST_PATH=\"$path\""
      exit 1
      ;;
  esac
}

main "$@"
