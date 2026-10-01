#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=_common.sh
source "$(dirname "$0")/_common.sh"

echo "Following systemd logs for ${HERMES_SERVICE_NAME}. Ctrl+C to exit."
sudo journalctl -u "$HERMES_SERVICE_NAME" -f
