# OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) is a personal AI assistant that connects to messaging platforms (Telegram, Discord, WhatsApp, etc.) and exposes a web dashboard for interaction. It is connected to the Ollama API for local model inference.

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
6. Secure the config directory (chown to uid 1000, chmod 600 on secrets)

At the end, the script prints the value for `OPENCLAW_GATEWAY_TOKEN` — you will need this for the next step.

### 2. Deploy via Coolify

Create a new Docker Compose service in Coolify using the `docker-compose.yml` from this directory. Set the following environment variable in Coolify:

| Variable | Description |
|---|---|
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

### Blocking IPv6 access to port 3333

By default Docker maps the port on both IPv4 and IPv6. To prevent the dashboard from being reachable over the Internet via IPv6, add an ip6tables rule on your Debian host:

```bash
sudo ip6tables -I INPUT -p tcp --dport 3333 -j DROP
```

To make this persist across reboots, install `iptables-persistent`:

```bash
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
```

## Data

Persistent data is stored on the host at `/home/openclaw/`:

| Host Path | Container Path | Purpose |
|---|---|---|
| `/home/openclaw/config/` | `/home/node/.openclaw` | Configuration, channel tokens, agent state |
| `/home/openclaw/workspace/` | `/home/node/.openclaw/workspace` | Agent workspace files |

## Networking

The container is connected to two external Docker networks:

| Network | Purpose |
|---|---|
| `coolify` | Inter-service communication with other Coolify-managed containers |
| `q8w484goc8kowgs48448wgwo` | Access to the Ollama API (reachable as `ollama-api` / `OLLAMA_HOST`) |

## ⚠️ Secrets

The following locations contain sensitive secrets:

| Location | Contains |
|---|---|
| Coolify environment variables | `OPENCLAW_GATEWAY_TOKEN` — authenticates access to the dashboard and API. Mark as sensitive/secret in Coolify. |
| `/home/openclaw/config/openclaw.json` | Channel tokens (Telegram bot token, etc.) and API keys. `chmod 600` is applied by `setup.sh`. |

## Updating

To update OpenClaw, re-run the setup script to rebuild the image:

```bash
./setup.sh
```

Then redeploy the container in Coolify. Your configuration and workspace data in `/home/openclaw/` are preserved.
