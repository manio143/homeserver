# OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) is a personal AI assistant that connects to messaging platforms (Telegram, Discord, WhatsApp, etc.) and exposes a web dashboard for interaction.

## Setup

Run the setup script on your Coolify server:

```bash
./setup.sh
```

The script will:

1. Clone the [openclaw repository](https://github.com/openclaw/openclaw) to `/tmp/openclaw`
2. Build the Docker image (`openclaw:local`)
3. Generate a gateway authentication token
4. Run the interactive onboarding wizard — follow the prompts
5. Prompt you for a Telegram bot token (optional, can be skipped)
6. Start the gateway container via Docker Compose

### Telegram Bot Setup

To use OpenClaw with Telegram, you need a bot token:

1. Open Telegram and chat with **@BotFather**
2. Send `/newbot` and follow the prompts to create a bot
3. Copy the bot token (format: `123456:ABC-DEF...`)
4. Enter it when prompted during setup

If you skip Telegram during initial setup, you can add it later:

```bash
docker compose -f docker-compose.yml --env-file .env \
  run --rm openclaw-gateway \
  node openclaw.mjs channels add --channel telegram --token "<YOUR_TOKEN>"
```

After adding a channel, restart the gateway:

```bash
docker compose -f docker-compose.yml --env-file .env restart
```

## Access

The dashboard is mapped to **port 3333** on the host. Access it at:

```
http://<your-server-ip>:3333/
```

You will need the gateway token (printed at the end of setup and stored in `.env`) to authenticate.

## Data

Persistent data is stored on the host at `~/openclaw/` (configurable via `HOME_OPENCLAW` env var):

| Host Path | Container Path | Purpose |
|---|---|---|
| `~/openclaw/config/` | `/home/node/.openclaw` | Configuration, channel tokens, agent state |
| `~/openclaw/workspace/` | `/home/node/.openclaw/workspace` | Agent workspace files |

## ⚠️ Secrets

The following files contain sensitive secrets and should be secured with appropriate file permissions:

| File | Contains |
|---|---|
| `openclaw/.env` | `OPENCLAW_GATEWAY_TOKEN` — authenticates access to the dashboard and API |
| `~/openclaw/config/openclaw.json` | Channel tokens (Telegram bot token, etc.) and API keys |

Recommended:

```bash
chmod 600 openclaw/.env
chmod 600 ~/openclaw/config/openclaw.json
```

**Do not commit the `.env` file to version control.** It is generated during setup and excluded from git via `.gitignore`.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `HOME_OPENCLAW` | `~/openclaw` | Host directory for persistent data |
| `OPENCLAW_GATEWAY_TOKEN` | (auto-generated) | Token for dashboard/API authentication |

## Updating

To update OpenClaw, re-run the setup script. It will pull the latest code and rebuild the image:

```bash
./setup.sh
```

The gateway container will be recreated with the new image. Your configuration and workspace data in `~/openclaw/` are preserved.
