# OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) is a personal AI assistant that connects to messaging platforms (Telegram, Discord, WhatsApp, etc.) and exposes a web dashboard for interaction.

## Setup

### 1. Build the image and run onboarding

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

At the end, the script prints the values for `HOME_OPENCLAW` and `OPENCLAW_GATEWAY_TOKEN` — you will need these for the next step.

### 2. Deploy via Coolify

Create a new Docker Compose service in Coolify using the `docker-compose.yml` from this directory. Set the following environment variables in Coolify:

| Variable | Description |
|---|---|
| `HOME_OPENCLAW` | Host directory for persistent data (default: `~/openclaw`) |
| `OPENCLAW_GATEWAY_TOKEN` | Token printed by `setup.sh` — authenticates dashboard/API access |

### Telegram Bot Setup

To use OpenClaw with Telegram, you need a bot token:

1. Open Telegram and chat with **@BotFather**
2. Send `/newbot` and follow the prompts to create a bot
3. Copy the bot token (format: `123456:ABC-DEF...`)
4. Enter it when prompted during `setup.sh`

## Access

The dashboard is mapped to **port 3333** on the host. Access it at:

```
http://<your-server-ip>:3333/
```

You will need the gateway token to authenticate (set as `OPENCLAW_GATEWAY_TOKEN` in Coolify).

## Data

Persistent data is stored on the host at `~/openclaw/` (configurable via `HOME_OPENCLAW` env var in Coolify):

| Host Path | Container Path | Purpose |
|---|---|---|
| `~/openclaw/config/` | `/home/node/.openclaw` | Configuration, channel tokens, agent state |
| `~/openclaw/workspace/` | `/home/node/.openclaw/workspace` | Agent workspace files |

## ⚠️ Secrets

The following locations contain sensitive secrets:

| Location | Contains |
|---|---|
| Coolify environment variables | `OPENCLAW_GATEWAY_TOKEN` — authenticates access to the dashboard and API |
| `~/openclaw/config/openclaw.json` | Channel tokens (Telegram bot token, etc.) and API keys |

Recommended:

```bash
chmod 600 ~/openclaw/config/openclaw.json
```

## Updating

To update OpenClaw, re-run the setup script to rebuild the image:

```bash
./setup.sh
```

Then redeploy the container in Coolify. Your configuration and workspace data in `~/openclaw/` are preserved.
