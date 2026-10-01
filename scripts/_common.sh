#!/usr/bin/env bash
# Shared helpers for Hermes system-service scripts.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export PATH="$HOME/.local/bin:$PATH"
HERMES_BIN="$(command -v hermes || true)"
HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
HERMES_SERVICE_NAME="${HERMES_SERVICE_NAME:-hermes-gateway}"

require_hermes() {
  [[ -n "$HERMES_BIN" ]] || { echo "✗ hermes command not found" >&2; exit 1; }
}

hermes_system() {
  require_hermes
  sudo env "HERMES_HOME=$HERMES_HOME_DIR" "$HERMES_BIN" gateway "$1" --system
}
