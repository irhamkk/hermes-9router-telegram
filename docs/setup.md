# Setup and Operations Guide

This guide assumes the intended deployment architecture:

```text
9Router -> GNU screen
Hermes Gateway -> systemd system service
Telegram -> Hermes messaging interface
```

The repository does not install 9Router. Have it working first, or be prepared for the installer to warn that the router is offline.

## 1. Prepare 9Router

Confirm the 9Router process is in screen:

```bash
screen -ls
```

If your session is named `9router`, you should see an entry containing `.9router`.

Confirm the API is reachable. Replace the key locally; never paste a real key into this repository:

```bash
curl -H 'Authorization: Bearer YOUR_KEY' \
  http://127.0.0.1:20128/v1/models
```

Use one of the returned model IDs as `ROUTER_MODEL`.

## 2. Clone and create the local environment file

```bash
git clone https://github.com/irhamkk/hermes-9router-telegram.git
cd hermes-9router-telegram
cp .env.example .env
chmod 600 .env
nano .env
```

Minimum example:

```env
TELEGRAM_BOT_TOKEN=123456789:REPLACE_WITH_REAL_TOKEN
TELEGRAM_ALLOWED_USERS=123456789
TELEGRAM_HOME_CHANNEL=123456789
TELEGRAM_GROUP_ALLOWED_CHATS=

ROUTER_BASE_URL=http://127.0.0.1:20128/v1
ROUTER_API_KEY=REPLACE_WITH_REAL_9ROUTER_KEY
ROUTER_MODEL=REPLACE_WITH_MODEL_ID
ROUTER_SCREEN_SESSION=9router
HERMES_SERVICE_NAME=hermes-gateway
```

Do not use spaces around `=`. Quote a value if you intentionally need spaces.

### Telegram IDs

For direct access, `TELEGRAM_ALLOWED_USERS` must contain numeric **user IDs**. It is not the same thing as a Telegram username.

For an entire Telegram group/forum chat, use `TELEGRAM_GROUP_ALLOWED_CHATS` with its numeric chat ID, often a negative value beginning with `-100`.

`TELEGRAM_HOME_CHANNEL` is optional. It is useful when cron/scheduled output should be delivered to a default Telegram destination.

## 3. Run the installer

```bash
./install.sh
```

The installer keeps the two process managers separate:

- it only **checks** the configured 9Router screen session;
- it installs Hermes Gateway using Hermes' supported **system-level systemd service**.

The live Hermes configuration normally ends up under:

```text
~/.hermes/config.yaml
~/.hermes/.env
```

The system service is configured to run as the normal user that launched the installer, not as root.

## 4. Verify the service

```bash
./scripts/status.sh
./scripts/healthcheck.sh
```

Follow Hermes logs with:

```bash
./scripts/logs.sh
```

Then send a direct message to the Telegram bot.

## 5. Normal operations

Hermes:

```bash
./scripts/start.sh
./scripts/stop.sh
./scripts/restart.sh
./scripts/status.sh
./scripts/logs.sh
```

9Router remains independent:

```bash
screen -ls
screen -r 9router
```

This separation avoids running two independent supervisors around Hermes. Hermes' installed systemd unit already owns the Gateway lifecycle.

## Troubleshooting

### 9Router screen session is missing

Check the configured name:

```bash
grep '^ROUTER_SCREEN_SESSION=' .env
screen -ls
```

If your existing screen session has another name, update `ROUTER_SCREEN_SESSION`. The repository deliberately does not guess the command used to launch your 9Router installation.

### 9Router API fails but screen exists

The process may be alive while the HTTP API is unhealthy or bound to another address/port.

Check:

```bash
curl -v http://127.0.0.1:20128/v1/models
```

If authentication is required, add the Bearer header. Also confirm `ROUTER_BASE_URL` includes `/v1` when your 9Router instance expects it.

### Hermes service is inactive

```bash
./scripts/status.sh
./scripts/logs.sh
```

Try:

```bash
./scripts/restart.sh
```

If the service definition is stale after a Hermes update, rerun:

```bash
sudo env "HERMES_HOME=$HOME/.hermes" "$(command -v hermes)" \
  gateway install --system --run-as-user "$USER" \
  --start-now --start-on-login
```

Do not create a second custom screen loop for Hermes on top of the systemd service.

### Bot token is valid but the bot ignores you

Check the configured Telegram user allowlist:

```bash
hermes config get TELEGRAM_ALLOWED_USERS
```

The ID must be your numeric Telegram user ID. If no allowlist is configured, current Hermes security defaults deny unauthorized users rather than making the gateway public.

### Wrong model / model-not-found errors

List exactly what 9Router exposes:

```bash
curl -H "Authorization: Bearer $ROUTER_API_KEY" \
  "$ROUTER_BASE_URL/models"
```

Then make `ROUTER_MODEL` match one of those IDs and rerun `./install.sh`, or update it directly with:

```bash
hermes config set model.default YOUR_MODEL_ID
./scripts/restart.sh
```

### `sudo: hermes: command not found`

The repository scripts avoid this common PATH problem by resolving the full Hermes executable path before invoking it under sudo. If you run commands manually, prefer:

```bash
sudo "$(command -v hermes)" gateway status --system
```

### Inspect current Hermes configuration

```bash
hermes config show
hermes config check
hermes config path
hermes config env-path
```

Avoid posting the contents of local secret files publicly.

## Public GitHub checklist

Before pushing:

```bash
./scripts/prepush-check.sh
git status
git diff --cached
```

Confirm:

- `.env` is not tracked;
- no Telegram bot token appears in staged files;
- no 9Router/provider key appears in staged files;
- no wallet/private/SSH key is present;
- no `~/.hermes` runtime/session data was copied into the repo.
