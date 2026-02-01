#!/bin/bash
# OpenClaw Gateway Entrypoint for Coolify
# Generates config and auth profiles from environment variables, then starts the gateway.
# Formerly clawdbot → moltbot → openclaw. Supports legacy env var prefixes.
set -e

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
LEGACY_CONFIG="$CONFIG_DIR/clawdbot.json"

mkdir -p "$CONFIG_DIR"

# --- Migrate legacy config if present ---
if [ ! -f "$CONFIG_FILE" ] && [ -f "$LEGACY_CONFIG" ]; then
  cp "$LEGACY_CONFIG" "$CONFIG_FILE"
  echo "Migrated legacy config: clawdbot.json → openclaw.json"
fi

# --- Gateway authentication ---
# Support both OPENCLAW_ and legacy CLAWDBOT_ env var prefixes.
GW_PASSWORD="${OPENCLAW_GATEWAY_PASSWORD:-${CLAWDBOT_GATEWAY_PASSWORD:-}}"
GW_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-${CLAWDBOT_GATEWAY_TOKEN:-}}"

AUTH_MODE="none"
if [ -n "${GW_PASSWORD}" ]; then
  AUTH_MODE="password"
elif [ -n "${GW_TOKEN}" ]; then
  AUTH_MODE="token"
else
  # Auto-generate a token if nothing is set
  GW_TOKEN=$(openssl rand -hex 32)
  AUTH_MODE="token"
  echo "============================================"
  echo "  Auto-generated gateway token:"
  echo "  $GW_TOKEN"
  echo "  Save this to access the Control UI!"
  echo "============================================"
fi

# --- Trusted proxies (Docker/Coolify network gateways) ---
DEFAULT_PROXIES="10.0.0.1,10.0.1.1,10.0.1.2,10.0.2.1,10.0.2.2,10.0.3.1,10.0.3.2,10.0.4.1,172.17.0.1,172.18.0.1,127.0.0.1"
TRUSTED_PROXIES="${CLAWDBOT_TRUSTED_PROXIES:-$DEFAULT_PROXIES}"
PROXIES_JSON=$(echo "$TRUSTED_PROXIES" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')

# --- Determine default model based on available API keys ---
DEFAULT_MODEL="${OPENCLAW_DEFAULT_MODEL:-anthropic/claude-haiku-4-5}"
echo "Default model: $DEFAULT_MODEL"

# --- Agent safeguards (opt-in) ---
# Only write optional settings when explicitly provided via env vars.
if [ -n "${MOLTBOT_CONTEXT_TOKENS:-}" ] || \
   [ -n "${MOLTBOT_COMPACTION_MODE:-}" ] || [ -n "${MOLTBOT_SESSION_IDLE_MINUTES:-}" ]; then
  echo "Agent safeguards (opt-in):"
  [ -n "${MOLTBOT_CONTEXT_TOKENS:-}" ] && echo "  contextTokens=$MOLTBOT_CONTEXT_TOKENS"
  [ -n "${MOLTBOT_COMPACTION_MODE:-}" ] && echo "  compaction=$MOLTBOT_COMPACTION_MODE"
  [ -n "${MOLTBOT_SESSION_IDLE_MINUTES:-}" ] && echo "  session idleMinutes=$MOLTBOT_SESSION_IDLE_MINUTES"
fi

# --- Write gateway config ---
# Deep-merge entrypoint-managed keys into existing config (preserves UI-configured settings).

# Build the entrypoint-managed config as a JSON object
MANAGED_CONFIG=$(cat <<JSONEOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789,
    "auth": {
      "mode": "${AUTH_MODE}"
    },
    "trustedProxies": ${PROXIES_JSON},
    "controlUi": {
      "allowInsecureAuth": true
    }
  },
  "web": {
    "enabled": true
  },
  "agents": {
    "defaults": {
      "workspace": "/home/node/.openclaw/workspace",
      "model": {
        "primary": "${DEFAULT_MODEL}"
      }
    }
  }
}
JSONEOF
)

# Inject auth credential via jq (safe escaping for special chars in passwords/tokens)
if [ "$AUTH_MODE" = "password" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg val "$GW_PASSWORD" \
    '.gateway.auth.password = $val')
elif [ "$AUTH_MODE" = "token" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg val "$GW_TOKEN" \
    '.gateway.auth.token = $val')
fi

# Add channels config (only if tokens are set)
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg token "$TELEGRAM_BOT_TOKEN" \
    '.channels.telegram = {
      "botToken": $token,
      "polling": {
        "retryDelayMs": 5000,
        "maxRetries": 10,
        "backoffMultiplier": 2
      }
    }')
fi
if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg token "$DISCORD_BOT_TOKEN" \
    '.channels.discord = { "botToken": $token }')
fi
if [ "${WHATSAPP_ENABLED:-}" = "true" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq \
    '.channels.whatsapp = { "enabled": true }')
fi
if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg token "$SLACK_BOT_TOKEN" \
    '.channels.slack = { "botToken": $token }')
  if [ -n "${SLACK_APP_TOKEN:-}" ]; then
    MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg token "$SLACK_APP_TOKEN" \
      '.channels.slack.appToken = $token')
  fi
fi

if [ -n "${MOLTBOT_CONTEXT_TOKENS:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --argjson val "$MOLTBOT_CONTEXT_TOKENS" \
    '.agents.defaults.contextTokens = $val')
fi
if [ -n "${MOLTBOT_COMPACTION_MODE:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg val "$MOLTBOT_COMPACTION_MODE" \
    '.agents.defaults.compaction.mode = $val')
fi
if [ -n "${MOLTBOT_SESSION_IDLE_MINUTES:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --argjson val "$MOLTBOT_SESSION_IDLE_MINUTES" \
    '.session.reset.idleMinutes = $val')
fi

# Deep-merge: existing config is the base, entrypoint-managed keys override.
# Back up existing config first so we can recover from bad merges (#1620).
if [ -f "$CONFIG_FILE" ]; then
  cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
  echo "Backed up existing config to $CONFIG_FILE.bak"
  EXISTING=$(cat "$CONFIG_FILE")
  # Strip deprecated keys from older entrypoints to avoid config validation failures.
  CLEANED=$(echo "$EXISTING" | jq 'del(
    .agents.defaults.maxConsecutiveToolErrors,
    .agents.defaults.maxToolCallsPerTurn,
    .agents.defaults.contextMessages,
    .agents.defaults.contextPruning,
    .cron.isolated
  )')
  if [ $? -eq 0 ] && [ -n "$CLEANED" ]; then
    EXISTING="$CLEANED"
    echo "Removed deprecated keys from existing $CONFIG_FILE"
  fi
  # jq '*' does recursive merge — managed config (right) wins on conflicts
  MERGED=$(echo "$EXISTING" "$MANAGED_CONFIG" | jq -s '.[0] * .[1]')
  if [ $? -eq 0 ] && [ -n "$MERGED" ]; then
    echo "$MERGED" > "$CONFIG_FILE"
    echo "Merged entrypoint config into existing $CONFIG_FILE"
  else
    echo "WARNING: Config merge failed, restoring backup"
    cp "$CONFIG_FILE.bak" "$CONFIG_FILE"
  fi
else
  echo "Creating new $CONFIG_FILE"
  echo "$MANAGED_CONFIG" | jq '.' > "$CONFIG_FILE"
fi

# --- Log channel tokens ---
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && echo "Telegram bot token detected"
[ -n "${DISCORD_BOT_TOKEN:-}" ] && echo "Discord bot token detected"
[ "${WHATSAPP_ENABLED:-}" = "true" ] && echo "WhatsApp enabled (pair via Control UI QR code)"
[ -n "${SLACK_BOT_TOKEN:-}" ] && echo "Slack bot token detected"

# --- Start gateway ---
exec openclaw gateway --bind lan --port 18789 --allow-unconfigured
