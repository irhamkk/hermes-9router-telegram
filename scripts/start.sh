#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

echo "→ Starting Hermes system service…"
hermes_system start
