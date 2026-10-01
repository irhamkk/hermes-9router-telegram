#!/usr/bin/env bash
# Bootstrap Hermes for an existing 9Router + Telegram setup.
# Architecture: 9Router runs separately in GNU screen; Hermes Gateway runs as a systemd system service.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

info() { printf '→ %s\n' "$*"; }
ok()   { printf '✓ %s\n' "$*"; }
warn() { printf '! %s\n' "$*"; }
die()  { printf '✗ %s\n' "$*" >&2; exit 1; }

printf '%s\n' '════════════════════════════════════════════════════'
printf '%s\n' '  Hermes + 9Router + Telegram — VPS installer'
printf '%s\n' '  9Router: screen | Hermes: systemd'
printf '%s\n' '════════════════════════════════════════════════════'

[[ "$(uname -s)" == "Linux" ]] || die "This installer targets Linux VPS hosts."
command -v systemctl >/dev/null 2>&1 || die "systemd/systemctl is required for the Hermes system service."
command -v sudo >/dev/null 2>&1 || die "sudo is required to install the Hermes system service."

# 1) Load local configuration.
[[ -f .env ]] || die "Missing .env. Run: cp .env.example .env && nano .env"
chmod 600 .env 2>/dev/null || true
set -a
# shellcheck disable=SC1091
source .env
set +a

ROUTER_BASE_URL="${ROUTER_BASE_URL:-http://127.0.0.1:20128/v1}"
ROUTER_SCREEN_SESSION="${ROUTER_SCREEN_SESSION:-9router}"
HERMES_SERVICE_NAME="${HERMES_SERVICE_NAME:-hermes-gateway}"

required=(TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS ROUTER_API_KEY ROUTER_MODEL)
for var in "${required[@]}"; do
  value="${!var:-}"
  [[ -n "$value" ]] || die "$var is empty in .env"
  [[ "$value" != CHANGE_ME* ]] || die "$var still contains a CHANGE_ME placeholder"
done
ok "Local configuration loaded"

# 2) Host dependencies.
for bin in curl git python3 screen; do
  command -v "$bin" >/dev/null 2>&1 || die "Missing '$bin'. Install it first (Ubuntu/Debian: sudo apt install $bin)."
done
ok "Host dependencies found"

# 3) Confirm the expected 9Router process/layout without taking ownership of it.
if [[ -n "$ROUTER_SCREEN_SESSION" ]]; then
  if screen -ls 2>/dev/null | grep -Fq ".${ROUTER_SCREEN_SESSION}"; then
    ok "9Router screen session found: $ROUTER_SCREEN_SESSION"
  else
    warn "No screen session named '$ROUTER_SCREEN_SESSION' was found."
    warn "This repo does not start/install 9Router; start your 9Router screen session separately."
  fi
fi

info "Checking 9Router API at ${ROUTER_BASE_URL}"
if curl -fsS --max-time 10 \
  -H "Authorization: Bearer ${ROUTER_API_KEY}" \
  "${ROUTER_BASE_URL%/}/models" >/dev/null; then
  ok "9Router API is reachable"
else
  warn "9Router API check failed. Hermes can still be configured, but it will not answer until 9Router is reachable."
fi

# 4) Install Hermes if necessary.
if ! command -v hermes >/dev/null 2>&1; then
  info "Installing Hermes Agent from the official installer"
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  hash -r
fi

HERMES_BIN="$(command -v hermes || true)"
[[ -n "$HERMES_BIN" ]] || die "Hermes installation finished but the 'hermes' command is not on PATH."
ok "Hermes available: $($HERMES_BIN --version 2>/dev/null || printf 'version unknown')"

# 5) Configure Hermes -> 9Router.
# Set provider first; Hermes may clear endpoint fields when the provider changes.
info "Configuring Hermes model route through 9Router"
"$HERMES_BIN" config set model.provider custom
"$HERMES_BIN" config set model.base_url "$ROUTER_BASE_URL"
"$HERMES_BIN" config set model.default "$ROUTER_MODEL"
"$HERMES_BIN" config set model.api_key "$ROUTER_API_KEY"
ok "Hermes model route configured"

# 6) Configure Telegram using current Hermes environment keys.
info "Configuring Telegram"
"$HERMES_BIN" config set TELEGRAM_BOT_TOKEN "$TELEGRAM_BOT_TOKEN"
"$HERMES_BIN" config set TELEGRAM_ALLOWED_USERS "$TELEGRAM_ALLOWED_USERS"

if [[ -n "${TELEGRAM_HOME_CHANNEL:-}" ]]; then
  "$HERMES_BIN" config set TELEGRAM_HOME_CHANNEL "$TELEGRAM_HOME_CHANNEL"
fi
if [[ -n "${TELEGRAM_GROUP_ALLOWED_CHATS:-}" ]]; then
  "$HERMES_BIN" config set TELEGRAM_GROUP_ALLOWED_CHATS "$TELEGRAM_GROUP_ALLOWED_CHATS"
fi
ok "Telegram credentials and allowlist configured"

# 7) Sanity-check Hermes config before installing the long-running service.
info "Running Hermes config check"
if "$HERMES_BIN" config check; then
  ok "Hermes config check passed"
else
  die "Hermes config check failed. Fix the reported configuration issue, then rerun ./install.sh."
fi

# 8) Install Hermes Gateway as a boot-time systemd system service.
# HERMES_HOME is passed explicitly so sudo cannot accidentally target root's profile.
TARGET_USER="${SUDO_USER:-$USER}"
HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"

info "Installing Hermes Gateway system service as user '$TARGET_USER'"
sudo env "HERMES_HOME=$HERMES_HOME_DIR" \
  "$HERMES_BIN" gateway install --system --run-as-user "$TARGET_USER" \
  --start-now --start-on-login
ok "Hermes Gateway systemd service installed and started"

printf '\n%s\n' '════════════════════════════════════════════════════'
printf '%s\n' '  Setup complete'
printf '%s\n' '════════════════════════════════════════════════════'
printf '9Router : screen session "%s" (managed separately)\n' "$ROUTER_SCREEN_SESSION"
printf 'Hermes  : systemd service "%s"\n' "$HERMES_SERVICE_NAME"
printf '\nRun: ./scripts/healthcheck.sh\n'
printf 'Logs: ./scripts/logs.sh\n'
printf 'Then message your Telegram bot.\n'
