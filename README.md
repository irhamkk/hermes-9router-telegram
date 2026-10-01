# Hermes + 9Router + Telegram — Reproducible VPS Setup

A small, secret-free repository for reproducing this deployment pattern on a Linux VPS:

```text
Telegram
   │
   ▼
Hermes Gateway
(systemd system service)
   │
   ▼
9Router
(GNU screen, localhost:20128)
   │
   ▼
LLM provider(s)
```

The important separation is intentional:

- **9Router is managed separately in GNU `screen`.** This repo checks it, but does not install or take ownership of it.
- **Hermes Gateway is managed by systemd.** It starts at boot and uses Hermes' own service lifecycle instead of a custom `screen` restart loop.
- **Telegram is allowlisted.** Only configured numeric Telegram user IDs can control the agent.
- **No live credentials belong in Git.** Secrets are supplied through a local `.env`, then written to the user's local Hermes configuration.

## Requirements

- Linux VPS using systemd (Ubuntu/Debian-style hosts are the main target)
- `bash`, `curl`, `git`, `python3`, `screen`, `sudo`
- A working 9Router instance running separately in a GNU `screen` session
- A 9Router API/client key
- A Telegram bot token from `@BotFather`
- Your numeric Telegram user ID

> This repository does **not** install 9Router. The default expected API endpoint is `http://127.0.0.1:20128/v1` and the default expected screen session is `9router`; both are configurable.

## Quick Start

```bash
git clone https://github.com/irhamkk/hermes-9router-telegram.git
cd hermes-9router-telegram

cp .env.example .env
nano .env

./install.sh
./scripts/healthcheck.sh
```

`install.sh` will:

1. validate `.env`;
2. confirm required host commands exist;
3. check the expected 9Router screen session and API endpoint;
4. install Hermes if `hermes` is not already available;
5. configure Hermes to use the 9Router OpenAI-compatible endpoint;
6. configure the Telegram bot token and user allowlist;
7. run `hermes config check`;
8. install and start Hermes Gateway as a **system-level systemd service** running as your normal user.

After that, message the Telegram bot.

## Configuration

Copy `.env.example` to `.env` and edit the local copy.

| Variable | Required | Purpose |
|---|---:|---|
| `TELEGRAM_BOT_TOKEN` | yes | Telegram bot token from BotFather |
| `TELEGRAM_ALLOWED_USERS` | yes | Comma-separated numeric Telegram **user IDs** allowed to use the bot |
| `TELEGRAM_HOME_CHANNEL` | no | Default Telegram destination for scheduled/cron output |
| `TELEGRAM_GROUP_ALLOWED_CHATS` | no | Comma-separated Telegram group/forum chat IDs |
| `ROUTER_BASE_URL` | yes | 9Router OpenAI-compatible base URL |
| `ROUTER_API_KEY` | yes | 9Router client/API key |
| `ROUTER_MODEL` | yes | Model ID exposed by 9Router `/v1/models` |
| `ROUTER_SCREEN_SESSION` | no | GNU screen session name used for the 9Router process check |
| `HERMES_SERVICE_NAME` | no | systemd service name; default profile normally uses `hermes-gateway` |

`TELEGRAM_ALLOWED_USERS` is deliberately a **user allowlist**, not a chat allowlist. Group-wide access, when wanted, belongs in `TELEGRAM_GROUP_ALLOWED_CHATS`.

## Service Commands

Hermes is **not** run in screen by this repository.

```bash
./scripts/start.sh
./scripts/stop.sh
./scripts/restart.sh
./scripts/status.sh
./scripts/logs.sh
```

The scripts call Hermes' system-service commands and systemd/journalctl as appropriate.

9Router remains a separate process. Typical manual checks:

```bash
screen -ls
screen -r 9router
```

Detach from screen with `Ctrl+A`, then `D`.

## Health Check

```bash
./scripts/healthcheck.sh
```

It checks four independent layers:

1. expected 9Router GNU screen session;
2. authenticated 9Router `/v1/models` response;
3. Hermes systemd service state;
4. Telegram Bot API token validity.

A valid Telegram token does not by itself prove that Hermes is replying correctly, so the final end-to-end test is still sending a message to your bot.

## Repository Layout

```text
.
├── .env.example
├── .gitattributes
├── .gitignore
├── LICENSE
├── README.md
├── SECURITY.md
├── install.sh
├── config/
│   ├── hermes.model.yaml
│   └── telegram.yaml
├── docs/
│   └── setup.md
└── scripts/
    ├── _common.sh
    ├── healthcheck.sh
    ├── logs.sh
    ├── prepush-check.sh
    ├── restart.sh
    ├── start.sh
    ├── status.sh
    └── stop.sh
```

Files under `config/` are documentation/reference examples only. The installer writes the live configuration into your local Hermes home (normally `~/.hermes/`), not into this Git repository.

## Security

Before every public push:

```bash
./scripts/prepush-check.sh
git status
git diff --cached
```

Make sure `.env`, private keys, provider credentials, and a populated `~/.hermes/` directory are not staged. See [`SECURITY.md`](SECURITY.md).

An agent connected to Telegram may have powerful local tools. Keep an explicit Telegram allowlist and do not expose the bot globally unless you intentionally understand the consequences.

## Updating Hermes

This repo intentionally does not silently update an existing Hermes installation. Check the installed version first:

```bash
hermes --version
```

When you intentionally update Hermes, re-run the health check afterwards. If Hermes reports that its installed systemd unit needs refreshing, reinstall/reconcile it with the current Hermes CLI rather than maintaining a hand-written systemd unit.

## Upstream Documentation

- Hermes messaging/gateway: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/
- Hermes Telegram setup: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/telegram
- Hermes provider setup: https://hermes-agent.nousresearch.com/docs/integrations/providers
- Hermes security guidance: https://hermes-agent.nousresearch.com/docs/user-guide/security

## License

MIT. See [`LICENSE`](LICENSE).
