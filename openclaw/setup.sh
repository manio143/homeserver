#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="/tmp/openclaw"
IMAGE_NAME="openclaw:local"

echo "========================================="
echo " OpenClaw Setup for Coolify"
echo "========================================="
echo ""

# --- Prerequisites ---
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose is not available." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed." >&2
  exit 1
fi

# --- Configuration ---
export HOME_OPENCLAW="${HOME_OPENCLAW:-$HOME/openclaw}"

mkdir -p "$HOME_OPENCLAW/config"
mkdir -p "$HOME_OPENCLAW/workspace"
# Ensure the container user (uid 1000) can write to these directories
chown -R 1000:1000 "$HOME_OPENCLAW" 2>/dev/null || true

echo "Data directory: $HOME_OPENCLAW"
echo ""

# --- Generate gateway token ---
if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  if command -v openssl >/dev/null 2>&1; then
    OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32)"
  else
    OPENCLAW_GATEWAY_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  fi
fi
export OPENCLAW_GATEWAY_TOKEN

# --- Clone and build ---
if [ -d "$REPO_DIR" ]; then
  echo "==> Updating existing openclaw clone..."
  git -C "$REPO_DIR" pull --ff-only
else
  echo "==> Cloning openclaw repository..."
  git clone https://github.com/openclaw/openclaw.git "$REPO_DIR"
fi

echo ""
echo "==> Building Docker image: $IMAGE_NAME"
echo "    (this may take several minutes)"
echo ""
docker build -t "$IMAGE_NAME" -f "$REPO_DIR/Dockerfile" "$REPO_DIR"

# --- Write .env file ---
ENV_FILE="$SCRIPT_DIR/.env"
cat > "$ENV_FILE" <<EOF
HOME_OPENCLAW=${HOME_OPENCLAW}
OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
EOF

echo ""
echo "==> Environment written to $ENV_FILE"

# --- Onboarding ---
echo ""
echo "========================================="
echo " Onboarding (interactive)"
echo "========================================="
echo ""
echo "When prompted:"
echo "  - Gateway bind: lan"
echo "  - Gateway auth: token"
echo "  - Gateway token: (will be pre-set)"
echo "  - Tailscale exposure: Off"
echo "  - Install Gateway daemon: No"
echo ""
docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" \
  run --rm \
  -e HOME=/home/node \
  -e OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
  openclaw-gateway \
  node openclaw.mjs onboard --no-install-daemon

# --- Telegram setup ---
echo ""
echo "========================================="
echo " Telegram Bot Setup"
echo "========================================="
echo ""
echo "To set up Telegram, you need a bot token from @BotFather on Telegram:"
echo "  1. Open Telegram and chat with @BotFather"
echo "  2. Run /newbot and follow the prompts"
echo "  3. Copy the bot token"
echo ""
read -rp "Enter your Telegram bot token (or press Enter to skip): " TELEGRAM_TOKEN

if [ -n "$TELEGRAM_TOKEN" ]; then
  docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" \
    run --rm \
    -e HOME=/home/node \
    -e OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
    openclaw-gateway \
    node openclaw.mjs channels add --channel telegram --token "$TELEGRAM_TOKEN"

  echo ""
  echo "Telegram bot configured successfully."
else
  echo "Skipping Telegram setup."
  echo "You can set it up later by running:"
  echo "  docker compose -f $SCRIPT_DIR/docker-compose.yml --env-file $ENV_FILE \\"
  echo "    run --rm openclaw-gateway \\"
  echo "    node openclaw.mjs channels add --channel telegram --token <YOUR_TOKEN>"
fi

# --- Start the gateway ---
echo ""
echo "========================================="
echo " Starting OpenClaw Gateway"
echo "========================================="
echo ""
docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d openclaw-gateway

echo ""
echo "========================================="
echo " Setup Complete!"
echo "========================================="
echo ""
echo "Dashboard:  http://<your-server-ip>:3333/"
echo "Token:      $OPENCLAW_GATEWAY_TOKEN"
echo "Config:     $HOME_OPENCLAW/config"
echo "Workspace:  $HOME_OPENCLAW/workspace"
echo "Env file:   $ENV_FILE"
echo ""
echo "Commands:"
echo "  docker compose -f $SCRIPT_DIR/docker-compose.yml --env-file $ENV_FILE logs -f"
echo "  docker compose -f $SCRIPT_DIR/docker-compose.yml --env-file $ENV_FILE restart"
echo "  docker compose -f $SCRIPT_DIR/docker-compose.yml --env-file $ENV_FILE down"
echo ""
echo "IMPORTANT: Secure the following files which contain secrets:"
echo "  - $ENV_FILE (contains OPENCLAW_GATEWAY_TOKEN)"
echo "  - $HOME_OPENCLAW/config/openclaw.json (contains channel tokens)"
