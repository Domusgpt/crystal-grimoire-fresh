#!/usr/bin/env bash
set -euo pipefail

CHANNEL="${FLUTTER_CHANNEL:-stable}"
INSTALL_DIR="${FLUTTER_HOME:-$HOME/.local/flutter}"
REPO_URL="https://github.com/flutter/flutter.git"

log() {
  echo "[setup] $1"
}

ensure_dependencies() {
  for cmd in git npm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Error: required command '$cmd' is not installed or not on PATH." >&2
      exit 1
    fi
  done
}

setup_flutter() {
  if [ ! -d "$INSTALL_DIR" ]; then
    log "Cloning Flutter ($CHANNEL) into $INSTALL_DIR"
    git clone --depth=1 --branch "$CHANNEL" "$REPO_URL" "$INSTALL_DIR"
  else
    log "Updating existing Flutter checkout at $INSTALL_DIR"
    git -C "$INSTALL_DIR" fetch --depth=1 origin "$CHANNEL"
    git -C "$INSTALL_DIR" checkout "$CHANNEL"
    git -C "$INSTALL_DIR" reset --hard "origin/$CHANNEL"
  fi

  export PATH="$INSTALL_DIR/bin:$PATH"
  log "Running flutter --version"
  "$INSTALL_DIR/bin/flutter" --version
}

setup_firebase_cli() {
  if command -v firebase >/dev/null 2>&1; then
    log "firebase-tools already installed (version $(firebase --version))"
    return
  fi

  log "Installing firebase-tools globally via npm"
  npm install -g firebase-tools --no-progress
  log "Installed firebase-tools version $(firebase --version)"
}

ensure_dependencies
setup_flutter
setup_firebase_cli

log "Setup complete. Add $INSTALL_DIR/bin to your PATH for future shells."
