#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/tmp/openclaw"
IMAGE_NAME="openclaw:local"

echo "========================================="
echo " OpenClaw Image Build & Setup"
echo "========================================="
echo ""
echo "This script builds the Docker image and runs"
echo "onboarding + channel setup. The container is"
echo "then deployed separately via Coolify."
echo ""

# --- Prerequisites ---
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed." >&2
  exit 1
fi

# --- Configuration ---
HOME_OPENCLAW="${HOME_OPENCLAW:-$HOME/openclaw}"

mkdir -p "$HOME_OPENCLAW/config"
mkdir -p "$HOME_OPENCLAW/workspace"
# Ensure the container user (uid 1000) can write to these directories
if ! chown -R 1000:1000 "$HOME_OPENCLAW" 2>/dev/null; then
  echo "WARNING: Could not set ownership of $HOME_OPENCLAW to uid 1000."
  echo "         You may need to run: sudo chown -R 1000:1000 $HOME_OPENCLAW"
fi

echo "Data directory: $HOME_OPENCLAW"
echo ""

# --- Generate gateway token ---
if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  if command -v openssl >/dev/null 2>&1; then
    OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32)"
  elif command -v python3 >/dev/null 2>&1; then
    OPENCLAW_GATEWAY_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  else
    echo "ERROR: openssl or python3 is required to generate a gateway token." >&2
    echo "       Alternatively, set OPENCLAW_GATEWAY_TOKEN before running this script." >&2
    exit 1
  fi
fi

echo "Generated gateway token: $OPENCLAW_GATEWAY_TOKEN"
echo ""

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
docker run --rm -it \
  -e HOME=/home/node \
  -e OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
  -v "$HOME_OPENCLAW/config:/home/node/.openclaw" \
  -v "$HOME_OPENCLAW/workspace:/home/node/.openclaw/workspace" \
  "$IMAGE_NAME" \
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
  docker run --rm -it \
    -e HOME=/home/node \
    -e OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
    -v "$HOME_OPENCLAW/config:/home/node/.openclaw" \
    -v "$HOME_OPENCLAW/workspace:/home/node/.openclaw/workspace" \
    "$IMAGE_NAME" \
    node openclaw.mjs channels add --channel telegram --token "$TELEGRAM_TOKEN"

  echo ""
  echo "Telegram bot configured successfully."
else
  echo "Skipping Telegram setup."
fi

# --- Done ---
echo ""
echo "========================================="
echo " Build & Setup Complete!"
echo "========================================="
echo ""
echo "Image built:  $IMAGE_NAME"
echo "Config:       $HOME_OPENCLAW/config"
echo "Workspace:    $HOME_OPENCLAW/workspace"
echo ""
echo "Next steps — create the container in Coolify with these environment variables:"
echo "  HOME_OPENCLAW=$HOME_OPENCLAW"
echo "  OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN"
echo ""
echo "IMPORTANT: Secure the following file which contains secrets:"
echo "  - $HOME_OPENCLAW/config/openclaw.json (contains channel tokens)"
