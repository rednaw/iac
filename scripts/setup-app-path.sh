#!/usr/bin/env bash
# Set which app the IAC devcontainer mounts at /workspaces/iac/app.
# Writes the path to ~/.config/iac-app-path and ensures your shell profile
# loads it into APP_HOST_PATH so GUI-launched Cursor/VS Code see it (macOS/Linux).
# Run from the host (not inside the devcontainer). See docs/application-deployment.md.
set -euo pipefail

CONFIG_DIR="${HOME}/.config"
PATH_FILE="${CONFIG_DIR}/iac-app-path"
MARKER="IAC devcontainer: app path (setup-app-path.sh)"

# Run on the host so we update the host's profile and path file; the devcontainer
# reads APP_HOST_PATH from the process that launched the editor.
running_in_devcontainer() {
  [[ -f /.dockerenv ]] || [[ -n "${DEVCONTAINER:-}" ]]
}

usage() {
  echo "Usage: $0 [PATH_TO_APP]"
  echo ""
  echo "  PATH_TO_APP  Absolute or relative path to your app repo (e.g. the one with iac.yml)."
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

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

ensure_snippet_macos() {
  local profile="$HOME/.zprofile"
  if [[ -f "$profile" ]] && grep -q "$MARKER" "$profile" 2>/dev/null; then
    return 0
  fi
  mkdir -p "$(dirname "$profile")"
  cat >> "$profile" << 'SNIPPET'

# IAC devcontainer: app path (setup-app-path.sh) — load into session for GUI-launched apps
[ -f ~/.config/iac-app-path ] && export APP_HOST_PATH=$(cat ~/.config/iac-app-path) && launchctl setenv APP_HOST_PATH "$APP_HOST_PATH"
SNIPPET
  echo "Added APP_HOST_PATH loader to $profile"
}

ensure_snippet_linux() {
  local profile="$HOME/.profile"
  if [[ -f "$profile" ]] && grep -q "$MARKER" "$profile" 2>/dev/null; then
    return 0
  fi
  mkdir -p "$(dirname "$profile")"
  cat >> "$profile" << 'SNIPPET'

# IAC devcontainer: app path (setup-app-path.sh) — load for session
[ -f ~/.config/iac-app-path ] && export APP_HOST_PATH=$(cat ~/.config/iac-app-path)
SNIPPET
  echo "Added APP_HOST_PATH loader to $profile"
}

main() {
  if running_in_devcontainer; then
    echo "This script must be run on the host, not inside the devcontainer."
    echo "It updates your host profile and ~/.config/iac-app-path so the editor process has APP_HOST_PATH."
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
    echo "Path to your app repo (directory containing iac.yml):"
    read -r path
    path=$(resolve_path "$path")
  fi

  mkdir -p "$CONFIG_DIR"
  echo "$path" > "$PATH_FILE"
  echo "Wrote $PATH_FILE: $path"

  local os
  os=$(detect_os)
  case "$os" in
    macos)
      ensure_snippet_macos
      launchctl setenv APP_HOST_PATH "$path"
      echo "Current session updated (launchctl setenv). Reopen the IAC devcontainer to see the app."
      ;;
    linux)
      ensure_snippet_linux
      echo "Profile updated. Log out and back in (or run: source ~/.profile in a new login shell), then Reopen in Container."
      ;;
    *)
      echo "Unsupported OS. Set APP_HOST_PATH in your environment and ensure your profile loads it. See docs/application-deployment.md."
      exit 1
      ;;
  esac
}

main "$@"
