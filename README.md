# Clawdbot on Coolify

Deploy [Clawdbot](https://molt.bot) gateway on [Coolify](https://coolify.io) with persistent configuration.

## Quick Start

1. Fork/clone this repo
2. In Coolify: **Add Resource** → **Docker Compose** → point to your repo
3. Set environment variables (see below)
4. Deploy
5. Run setup in the container terminal
6. Restart the container

## Environment Variables

Set these in Coolify's environment variables section:

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAWDBOT_GATEWAY_TOKEN` | Yes | Shared secret for gateway access. Generate with: `openssl rand -hex 32` |
| `GOOGLE_API_KEY` | Yes* | Your Google AI API key from [AI Studio](https://aistudio.google.com/apikey) |
| `ANTHROPIC_API_KEY` | Yes* | Your Anthropic API key (if using Claude instead of Gemini) |

*At least one provider API key is required.

## First-Time Setup

After the first deployment, the gateway starts but isn't configured yet. You need to run setup once:

### Option 1: Coolify Terminal
1. Go to your service in Coolify
2. Click **Terminal**
3. Run: `clawdbot setup`

### Option 2: SSH + Docker
```bash
# SSH into your Coolify server
ssh user@your-server

# Find the container
docker ps | grep clawdbot

# Run setup
docker exec -it <container_name> clawdbot setup
```

After setup completes, **restart the container** in Coolify.

## Verify It's Working

```bash
curl https://your-domain.com/health
```

You should get a response (not 503).

## Architecture

```
┌─────────────────────────────────────────┐
│  Coolify                                │
│  ┌───────────────────────────────────┐  │
│  │  clawdbot-gateway container       │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  clawdbot gateway :18789    │  │  │
│  │  └─────────────────────────────┘  │  │
│  │         │              │          │  │
│  │    ┌────┴────┐   ┌─────┴─────┐    │  │
│  │    │ config  │   │ workspace │    │  │
│  │    │ volume  │   │  volume   │    │  │
│  │    └─────────┘   └───────────┘    │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Volumes

Two named volumes persist data across restarts and redeployments:

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `clawdbot_state` | `/home/node/.clawdbot` | Config, sessions, agent state |
| `clawdbot_workspace` | `/home/node/clawd` | Workspace files |

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Node 22 image with clawdbot installed globally |
| `entrypoint.sh` | Starts the gateway process |
| `docker-compose.yaml` | Coolify-compatible compose with volumes |

## Updating Clawdbot

To update to a new version of clawdbot:

1. In Coolify, click **Redeploy** (this rebuilds the image with latest npm package)
2. The volumes preserve your config, so no re-setup needed

## Troubleshooting

### 503 Error
The gateway isn't running. Check container logs:
- If "Missing config" → Run `clawdbot setup` in the container
- If permission errors → Check volume permissions

### Gateway won't start
Try running with debug:
```bash
docker exec -it <container> clawdbot gateway --verbose
```

### Config lost after redeploy
Make sure you're using **Redeploy**, not delete + recreate. Named volumes persist across redeployments but not if you delete the service entirely.

## License

MIT
