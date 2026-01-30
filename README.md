# Moltbot on Coolify

> **Personal template by [@RJuro](https://github.com/RJuro).** Assumes familiarity with Docker, Coolify, and command-line tools.

Deploy the [Moltbot](https://molt.bot) gateway on [Coolify](https://coolify.io) with persistent configuration, auto-generated auth, and API key management.

Uses the [`moltbot@beta`](https://www.npmjs.com/package/moltbot) npm package (the official release channel by the moltbot team). The project was formerly known as "clawdbot" — some env vars retain the `CLAWDBOT_` prefix for backward compatibility.

## Quick Start

1. Fork this repo
2. In Coolify: **Add Resource** → **Docker Compose** → point to your fork
3. Set environment variables (see below)
4. Deploy

No manual setup step needed — the entrypoint auto-generates config and auth profiles from your environment variables.

## Environment Variables

Set these in your Coolify resource settings.

### Authentication (auto-generated if omitted)

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAWDBOT_GATEWAY_PASSWORD` | Recommended | Gateway password for Control UI access |
| `CLAWDBOT_GATEWAY_TOKEN` | No | Token auth (alternative to password) |

If neither is set, a random token is auto-generated and printed in container logs.

### AI Provider Keys (at least one required)

| Variable | Provider |
|----------|----------|
| `ANTHROPIC_API_KEY` | Anthropic (Claude) |
| `GOOGLE_API_KEY` | Google AI (Gemini) |
| `OPENAI_API_KEY` | OpenAI (GPT) |
| `OPENROUTER_API_KEY` | OpenRouter (multi-provider) |

### Channel Integrations (optional)

| Variable | Channel |
|----------|---------|
| `TELEGRAM_BOT_TOKEN` | Telegram |
| `DISCORD_BOT_TOKEN` | Discord |

### Token Usage Safeguards (optional)

These settings prevent runaway API costs from tool-call loops, context bloat, and polling issues. Defaults are conservative and should work for most deployments.

| Variable | Default | Description |
|----------|---------|-------------|
| `MOLTBOT_MAX_TOOL_ERRORS` | `3` | Abort after N consecutive identical tool errors (prevents infinite loop burns) |
| `MOLTBOT_MAX_TOOL_CALLS` | `25` | Max tool invocations per agent turn (hard cap) |
| `MOLTBOT_CONTEXT_MESSAGES` | `50` | Max messages kept in session context (limits token accumulation) |
| `MOLTBOT_COMPACTION_MODE` | `safeguard` | Context compaction strategy (`safeguard` = adaptive chunking with fallback) |

**What these protect against:**
- **Tool-call infinite loops**: When a model repeatedly makes the same failing tool call (e.g., wrong parameter name), `MAX_TOOL_ERRORS=3` stops it after 3 identical errors instead of 25+.
- **Context dragging**: Large tool outputs (JSON schemas, logs) get appended to session history and carried forward. `CONTEXT_MESSAGES=50` caps how much history the model processes per turn.
- **Cron session bloat**: Cron jobs are configured to run in isolated sessions (fresh context per run) so they don't accumulate history.
- **Telegram polling storms**: Telegram channel config includes retry backoff (5s base, 2x multiplier, max 10 retries) to prevent tight reconnect loops on transient network errors.

## Architecture

- **Single service**: `moltbot-gateway` on port 18789
- **Health check**: `curl http://localhost:18789/health` (30s interval, 60s startup grace)
- **Proxy labels**: Both Traefik and Caddy labels included for Coolify compatibility
- **Volumes**: Config persists across redeployments

## Volumes

| Volume | Container Path | Purpose |
|--------|---------------|---------|
| `moltbot_state` | `/home/node/.clawdbot` | Config, sessions, auth profiles |
| `moltbot_workspace` | `/home/node/clawd` | Workspace files |

## How It Works

The `entrypoint.sh` script:
1. Writes `clawdbot.json` gateway config from environment variables
2. Generates `auth-profiles.json` with any API keys provided
3. Configures `gateway.bind=lan` so the gateway is reachable from Coolify's proxy network
4. Starts the gateway with `--allow-unconfigured` as fallback

## Troubleshooting

**502 Bad Gateway**: Gateway not reachable from proxy.
- Check health: `docker exec <container> curl localhost:18789/health`
- Verify the container is on the `coolify` network
- Ensure `gateway.bind` is `lan` (handled automatically by entrypoint)

**503 Error**: Gateway process crashed. Check logs: `docker logs <container>`

**Config lost after redeploy**: Use **Redeploy** in Coolify, not delete + recreate. Named volumes persist across redeployments.

**No API keys warning**: Set at least one provider key (ANTHROPIC_API_KEY, GOOGLE_API_KEY, etc.) in Coolify environment variables.
