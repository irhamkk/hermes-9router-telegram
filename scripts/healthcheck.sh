#!/usr/bin/env bash
# Verify the real deployment shape:
# 1) 9Router screen session, 2) 9Router API, 3) Hermes systemd, 4) Telegram token.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
else
  echo "[WARN] .env not found; secret-dependent checks will be skipped."
fi

ROUTER_BASE_URL="${ROUTER_BASE_URL:-http://127.0.0.1:20128/v1}"
ROUTER_SCREEN_SESSION="${ROUTER_SCREEN_SESSION:-9router}"
HERMES_SERVICE_NAME="${HERMES_SERVICE_NAME:-hermes-gateway}"

PASS=0
FAIL=0
SKIP=0
ok()   { printf '  [OK]   %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }
skip() { printf '  [SKIP] %s\n' "$1"; SKIP=$((SKIP+1)); }

printf '%s\n' 'Hermes + 9Router + Telegram health check'
printf '%s\n' '--------------------------------------------'

# Layer 1: 9Router GNU screen session.
if [[ -z "$ROUTER_SCREEN_SESSION" ]]; then
  skip "9Router screen-session check disabled"
elif ! command -v screen >/dev/null 2>&1; then
  fail "GNU screen is installed"
elif screen -ls 2>/dev/null | grep -Fq ".${ROUTER_SCREEN_SESSION}"; then
  ok "9Router screen session is running (${ROUTER_SCREEN_SESSION})"
else
  fail "9Router screen session is running (${ROUTER_SCREEN_SESSION})"
fi

# Layer 2: 9Router OpenAI-compatible API.
if [[ -n "${ROUTER_API_KEY:-}" && "${ROUTER_API_KEY}" != CHANGE_ME* ]]; then
  if curl -fsS --max-time 10 \
    -H "Authorization: Bearer ${ROUTER_API_KEY}" \
    "${ROUTER_BASE_URL%/}/models" >/dev/null 2>&1; then
    ok "9Router API responds (${ROUTER_BASE_URL})"
  else
    fail "9Router API responds (${ROUTER_BASE_URL})"
  fi
else
  skip "9Router API check: ROUTER_API_KEY is not configured"
fi

# Layer 3: Hermes systemd system service.
if ! command -v systemctl >/dev/null 2>&1; then
  fail "systemctl is available"
elif systemctl is-active --quiet "$HERMES_SERVICE_NAME" 2>/dev/null; then
  ok "Hermes systemd service is active (${HERMES_SERVICE_NAME})"
else
  fail "Hermes systemd service is active (${HERMES_SERVICE_NAME})"
fi

# Layer 4: Telegram Bot API credentials.
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && "${TELEGRAM_BOT_TOKEN}" != CHANGE_ME* ]]; then
  response="$(curl -fsS --max-time 10 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" 2>/dev/null || true)"
  if [[ "$response" == *'"ok":true'* ]]; then
    ok "Telegram bot token is valid"
  else
    fail "Telegram bot token is valid"
  fi
else
  skip "Telegram API check: TELEGRAM_BOT_TOKEN is not configured"
fi

printf '%s\n' '--------------------------------------------'
printf '  Passed: %d   Failed: %d   Skipped: %d\n' "$PASS" "$FAIL" "$SKIP"

if [[ "$FAIL" -eq 0 ]]; then
  echo "Stack looks healthy."
else
  echo "One or more checks failed. See docs/setup.md and ./scripts/logs.sh."
  exit 1
fi
