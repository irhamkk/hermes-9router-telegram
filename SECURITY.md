# Security Notes

This repository is intentionally configuration-only. It must never contain live credentials.

## Never commit

- `.env`
- Telegram bot tokens
- 9Router/API-provider keys
- wallet/private keys, seed phrases, SSH keys, or cloud credentials
- a copy of `~/.hermes/` containing secrets or session data

The included `.gitignore` blocks common local-secret files, but `.gitignore` is not a security boundary. Always inspect `git diff --cached` before pushing.

## Telegram access

Keep `TELEGRAM_ALLOWED_USERS` restricted to trusted numeric Telegram user IDs. Do not enable global allow-all access for an agent that can execute shell commands.

## If a secret was committed

Treat it as compromised even if the commit is later deleted. Rotate/revoke the credential first, then clean the Git history if needed.
