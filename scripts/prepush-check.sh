#!/usr/bin/env bash
# Lightweight guardrail before publishing this repository.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PASS=0
FAIL=0
ok()   { printf '  [OK]   %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This check is intended to run inside a Git repository."
  exit 2
fi

if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  fail ".env is not tracked"
else
  ok ".env is not tracked"
fi

if git ls-files | grep -Eq '(^|/)(\.hermes)(/|$)'; then
  fail "No .hermes runtime directory is tracked"
else
  ok "No .hermes runtime directory is tracked"
fi

if git ls-files | grep -Ei '(^|/).*(private[_-]?key|seed|mnemonic|credentials?).*$' >/dev/null; then
  fail "No credential-like filenames are tracked"
else
  ok "No credential-like filenames are tracked"
fi

leaks="$(git grep -nE '(TELEGRAM_BOT_TOKEN|ROUTER_API_KEY)=' -- . 2>/dev/null   | grep -Ev '(CHANGE_ME|REPLACE_WITH|YOUR_|\$ROUTER_API_KEY)' || true)"
if [[ -n "$leaks" ]]; then
  fail "No suspicious credential assignments exist in tracked files"
  printf '%s\n' "$leaks"
else
  ok "No suspicious credential assignments exist in tracked files"
fi

printf '%s\n' '--------------------------------------------'
printf 'Passed: %d   Failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
