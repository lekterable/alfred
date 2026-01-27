RJuro
rjuro
coolify
coolify
hey there would love to try clawdbot in a containerized manner, while keeping things as simple as possible, then I thought that maybe there's an image for clawdbot to be used easily through coolify, but couldn't find any has anyone deployed through coolify? did you just run the setup.sh via the console? just looking for info before diving in
Looking for guidance on deployment on VPS via coolify
feva

OP
 — 15/01/2026, 13.51
hey there
would love to try clawdbot in a containerized manner, while keeping things as simple as possible, then I thought that maybe there's an image for clawdbot to be used easily through coolify, but couldn't find any

has anyone deployed through coolify? did you just run the setup.sh via the console?

just looking for info before diving in
Krill 🦐:lobster:
APP
 — 15/01/2026, 13.51
Hey! Great question 🦐

There's no official Clawdbot Docker image yet (it's on the roadmap), but deploying via Coolify is totally doable:

Options for Coolify:

Custom Docker Image - Build your own from the repo's Dockerfile (if it has one) or just use Coolify's "Docker" template and point it to the GitHub repo

Shell Script Method - Use Coolify's "Docker Run" or "Custom Command" option and run the setup.sh script in your console

General approach:
Create a new service in Coolify
Choose "Docker" or "Custom"
Point to the Clawdbot repo or run setup.sh directly
Set environment variables for providers (Discord, OpenAI, etc.)

Note: I don't have specific Coolify deployment docs in the repo, but the setup.sh handles most of the initial configuration. Make sure to back up your ~/.clawdbot/ config after setup.
Anyone in the community deployed Clawdbot via Coolify? Would love to hear what worked for you! 🎉

https://docs.clawd.bot/start/installation for reference on the install process.
adokce — 17/01/2026, 01.44
i think i'm about to try do this
Krill 🦐:lobster:
APP
 — 17/01/2026, 01.44
There's no official Clawdbot image for Coolify yet, but you can absolutely deploy it! Here's how:

Option 1: Build from source in Coolify

Coolify can build from your cloned repo:
Fork/clone clawdbot repo
In Coolify: "Create new resource" → "GitHub Repository"
Set build pack to "Dockerfile"
Set port to 18789
Set these environment variables:
NODE_ENV=production
CLAWDBOT_STATE_DIR=/home/node/.clawdbot
CLAWDBOT_WORKSPACE=/home/node/clawd

Option 2: Pre-build and use Docker Hub

Build locally first:
git clone https://github.com/clawdbot/clawdbot.git
cd clawdbot
docker build -t yourusername/clawdbot:latest .
docker push yourusername/clawdbot:latest


Then in Coolify just point to your image.

Important notes for Coolify:

Persistence - Set these volumes:
~/.clawdbot → /home/node/.clawdbot
~/clawd → /home/node/clawd

After install - You'll need to run onboarding:
   docker exec -it <container> pnpm clawdbot onboard
   

   Or use the CLI container approach from the docs

Port - Gateway listens on 18789 by default

WhatsApp - Requires persistent sessions, so the volume mount is critical

For simplest path: If Coolify supports it, use the docker-setup.sh flow locally first to generate your config, then move that config + volumes to Coolify.

Want me to dig up any specific docs or help with a particular step? 🦐
adokce — 17/01/2026, 01.49
@Krill 🦐 - thanks for the tips. I mostly use telegram for messaging, i do have "minimax.io" (MiniMax-M2.1 ) subscription, "z.ai" (GLM 4.7) subscription - these are things to keep in mind for my setup. Is there somethign else I need to know before I try ti deploy clawdbot on coolify
Krill 🦐:lobster:
APP
 — 17/01/2026, 01.49
Perfect! With MiniMax + Z.AI + Telegram, here's what you need to know:

Your Model Config
Both providers use simple API keys:

{
  env: {
    MINIMAX_API_KEY: "your-minimax-key",
    ZAI_API_KEY: "your-zai-key"
  },
  agents: {
    defaults: {
      model: { primary: "minimax/MiniMax-M2.1" },
      models: {
        "minimax/MiniMax-M2.1": { alias: "minimax" },
        "zai/glm-4.7": { alias: "glm" }
      }
    }
  }
}


Models you'll use:
minimax/MiniMax-M2.1 - your default (coding-focused, 200k context)
zai/glm-4.7 - fallback or switch via /model glm

Telegram Setup
In your config:
{
  channels: {
    telegram: {
      allowFrom: ["YOUR_TELEGRAM_USER_ID"]  // numeric ID, not @username
    }
  }
}


To find your ID: DM @userinfobot on Telegram, then use that number.

Coolify-Specific Notes
Environment variables - Add MINIMAX_API_KEY and ZAI_API_KEY in Coolify's env vars section

Persistence is critical - Set these volumes:
~/.clawdbot → persistent volume (sessions, credentials, config)
~/clawd → persistent volume (workspace, memory files)

Port - Expose port 18789

After deployment - You'll need to:
Run onboarding: clawdbot onboard --auth-choice telegram (or use the CLI container)
Configure your providers via clawdbot configure

Health check - Coolify health check: http://your-ip:18789/health (or configure a tokenized health endpoint)

Quick Test Before Full Deploy
If you have CLI access on the VPS, test locally first:
git clone https://github.com/clawdbot/clawdbot.git
cd clawdbot
pnpm install
pnpm clawdbot onboard  # pick Telegram + MiniMax + Z.AI


Then copy ~/.clawdbot/clawdbot.json and your API keys to Coolify.

One Gotcha
Telegram needs the bot token from @BotFather. Get that before deploying.

Want me to dig up any specific config examples or troubleshooting tips? 🦐
adokce — 17/01/2026, 01.53
how should i set up the persistence stuff? also since i use coolify cloud and i dont own a domain for my coolify setup yet - the urls coolify generates for my apps are all http (not https) - is that something i need to fix or will clawdbot work anyway?
Krill 🦐:lobster:
APP
 — 17/01/2026, 01.54
Persistence in Coolify
In Coolify, add these persistent volumes to your resource:

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| /var/lib/clawdbot/clawdbot | /home/node/.clawdbot | Config, credentials, sessions |
| /var/lib/clawdbot/clawd | /home/node/clawd | Workspace (AGENTS.md, SOUL.md, memory) |

In Coolify UI:
Go to your resource → Volumes tab
Add each mount as a named volume or bind mount
Named volumes are easier (Coolify manages them)

Recommended: Use named volumes so Coolify handles backups/snapshots automatically.

---
HTTP vs HTTPS
Short answer: It depends on what you're exposing.

What works on HTTP:
Direct bot usage - If you connect via CLI or the Control UI on the same network
Telegram polling - If you use long polling instead of webhooks
WhatsApp - Uses QR pairing, not webhooks

What needs HTTPS:
Telegram webhooks - Telegram REQUIRES HTTPS for webhooks
WhatsApp/Meta webhooks - Meta also requires HTTPS
Public Control UI access - Browser warns about insecure connections

Your Options:
Option 1: Use Polling (simplest for HTTP-only)
{
  channels: {
    telegram: {
      mode: "polling"  // instead of "webhook"
    }
  }
}

No webhook = no HTTPS requirement from Telegram.

Option 2: Let Coolify handle HTTPS
Coolify Cloud should provision SSL automatically for your coolify.io subdomain. If it's not working, check:
Domain is properly configured in Coolify
DNS is pointing to Coolify's servers

Option 3: Use Tailscale (free, private)
If Coolify's HTTPS isn't working, set up Tailscale on your VPS and use clawdbot gateway --tailscale serve for secure access without a domain.

---

Recommended Setup for Your Case
Since you're on Coolify Cloud without a custom domain:

Use Telegram polling (no webhook = no HTTPS needed)
Access Control UI locally via SSH tunnel or Tailscale
Add the volumes for persistence

// Your minimal config for this setup
{
  env: {
    MINIMAX_API_KEY: "sk-...",
    ZAI_API_KEY: "sk-..."
  },
  channels: {
    telegram: {
      mode: "polling",  // avoids HTTPS requirement
      allowFrom: ["YOUR_TELEGRAM_ID"]
    }
  },
  agents: {
    defaults: {
      workspace: "/home/node/clawd",
      model: { primary: "minimax/MiniMax-M2.1" }
    }
  }
}


This gives you a working setup without worrying about HTTPS. Later you can switch to webhooks if you get a domain with SSL.

Does that help? 🦐
adokce — 17/01/2026, 02.24
i just clicked Deploy on coolify and I see this - what did I mess up?
 2026-Jan-17 01:23:10.777563 Starting deployment of clawdbot/clawdbot:main to ubuntu-4gb-nbg1-1.
2026-Jan-17 01:23:12.095219 Preparing container with helper image: ghcr.io/coollabsio/coolify-helper:1.0.12
2026-Jan-17 01:23:16.769632 ----------------------------------------
2026-Jan-17 01:23:16.829468 Importing clawdbot/clawdbot:main (commit sha fa2b92bb00c290a22675c0532e1b66b19be036f7) to /artifacts/g4k40k44ko8wsskcokkogs4c.
2026-Jan-17 01:23:30.666346 Image not found (gcowksss0c0s00ckoosck8oo:fa2b92bb00c290a22675c0532e1b66b19be036f7). Building new image.
2026-Jan-17 01:23:34.274111 ----------------------------------------
Expand
message.txt
7 KB
Krill 🦐:lobster:
APP
 — 17/01/2026, 02.25
That's not an error you caused - it looks like a leftover instruction file. Can you share:

What you see in the Coolify logs (the actual error/output)
Is the container running or did it crash?

That .txt file in media/inbound/ is just an instruction template that got created somehow - it shouldn't appear unless something tried to send media.

Quick sanity check:
Is the container actually running? Check in Coolify → resource → "Status"
Can you access the Control UI at http://YOUR-COOLIFY-APP.coolify.io:18789/?

The file you posted is NOT an error from Clawdbot - it's just a template for sending media back. It might have been created if:
Someone tested media handling
There's a misconfigured skill trying to process media
A previous deployment left it behind

If the container won't start, paste the Coolify logs here and I'll help debug. 🦐
adokce — 17/01/2026, 02.47
please take a look at this log - the build of my clawdbot fails when i try to Deploy on coolify:
 Deployment is Failed
2026-Jan-17 01:34:29.012716 Starting deployment of clawdbot/clawdbot:main to ubuntu-4gb-nbg1-1.
2026-Jan-17 01:34:29.845321 Preparing container with helper image: ghcr.io/coollabsio/coolify-helper:1.0.12
2026-Jan-17 01:34:32.861947 ----------------------------------------
2026-Jan-17 01:34:32.875149 Importing clawdbot/clawdbot:main (commit sha faba508fe0ae4dd4de453f4eccb62e452950880d) to /artifacts/qgkkcw8wgsogsgkggc4gkkoo.
2026-Jan-17 01:34:46.580805 ----------------------------------------
Expand
message.txt
7 KB
Krill 🦐:lobster:
APP
 — 17/01/2026, 02.47
I can see you attached a file, but it looks like the same instruction template from before - not the actual build log.

Can you share the actual build log from Coolify?

In Coolify:
Go to your resource → Logs tab (or Deployment logs)
Copy the full error/output and paste it here

Or just describe:
What the error says (the red/yellow text)
At what step it fails (building, starting, health check?)

That will help me spot what went wrong. 🦐
adokce — 17/01/2026, 02.51
Deployment is Failed
Starting deployment of clawdbot/clawdbot:main to ubuntu-4gb-nbg1-1.
Preparing container with helper image: ghcr.io/coollabsio/coolify-helper:1.0.12
----------------------------------------
Importing clawdbot/clawdbot:main (commit sha faba508fe0ae4dd4de453f4eccb62e452950880d) to /artifacts/qgkkcw8wgsogsgkggc4gkkoo.
----------------------------------------
Docker build cache is disabled. It will not be used during the build process.
Building docker image started.
To check the current progress, click on Show Debug Logs.
========================================
Deployment failed: Command execution failed (exit code 1): docker exec qgkkcw8wgsogsgkggc4gkkoo bash -c 'bash /artifacts/build.sh'
Error: #0 building with "default" instance using docker driver
#1 [internal] load build definition from Dockerfile...
#7 [ 7/14] COPY ui/package.json ./ui/package.json
#7 CACHED
#8 [ 3/14] RUN corepack enable
#8 CACHED
#9 [ 4/14] WORKDIR /app
#9 CACHED
#10 [ 6/14] COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
#10 CACHED
#11 [ 8/14] COPY patches ./patches
#11 ERROR: failed to calculate checksum of ref xzo8c9a4vgk5inzk5lokm2e5x::oatdcjayjt9wvd5g3pnatqo8j: "/patches": not found
#12 [ 2/14] RUN curl -fsSL https://bun.sh/install | bash
#12 CANCELED
------
[ 8/14] COPY patches ./patches:
------
Dockerfile:27
--------------------
25 |     COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
26 |     COPY ui/package.json ./ui/package.json
27 | >>> COPY patches ./patches
28 |     COPY scripts ./scripts
29 |
--------------------
ERROR: failed to build: failed to solve: failed to compute cache key: failed to calculate checksum of ref xzo8c9a4vgk5inzk5lokm2e5x::oatdcjayjt9wvd5g3pnatqo8j: "/patches": not found
exit status 1
========================================
Deployment failed. Removing the new version of your application.
Krill 🦐:lobster:
APP
 — 17/01/2026, 02.51
Found the issue! The build fails because the patches folder is missing:

ERROR: failed to calculate checksum of ref ...: "/patches": not found


The problem: The patches folder is either:
A git submodule that wasn't initialized
Missing from the shallow clone Coolify did

Quick fix options:

Option 1: Use a full clone (not shallow)
In Coolify, look for "Git settings" or "Build settings" and:
Disable "Shallow clone" or set depth to something large (like 50)
Or use this custom build command instead of relying on the Dockerfile directly
Option 2: Custom Dockerfile that doesn't need patches
Create your own Dockerfile in your fork that skips the patches:

FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# Skip patches folder if missing
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
# COPY patches ./patches  # Comment this out or remove
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

CMD ["node", "dist/index.js"]
Option 3: Clone with submodules
If patches is a submodule, in Coolify's custom build command:
git clone --recurse-submodules https://github.com/clawdbot/clawdbot.git
cd clawdbot
# then build


---

Which approach works best for you? Do you have a fork of clawdbot, or are you using the main repo directly in Coolify? 🦐
adokce — 17/01/2026, 03.12
can you check what is the "patches" folder in clawdbot repo? why is it in dockerfile but i cant see it in the repo root folder?
Krill 🦐:lobster:
APP
 — 17/01/2026, 03.12
Found it! Here's what's happening:

What patches is
The patches folder contains custom patches for npm packages that need to be applied after installation. The postinstall.js script runs after pnpm install and applies these patches to packages in node_modules/.

It contains patches for:
@mariozechner__pi-agent-core.patch
@mariozechner__pi-ai@0.45.7.patch
@mariozechner__pi-coding-agent.patch
playwright-core@1.57.0.patch
qrcode-terminal.patch

These patches modify external packages to fix bugs or add features that haven't been merged upstream yet.

---
Why Coolify can't find it
Coolify is doing a shallow clone (no git history) which sometimes doesn't properly include all files/folders, or the build context is missing the patches folder.

---

Fix: Disable shallow clone in Coolify
In your Coolify resource settings:

Find "Git settings" or "Advanced settings"
Set "Git Clone Depth" to 0 (unlimited) or disable "Shallow Clone"
Redeploy

This ensures all files, including patches/, are included in the build context.

---
Alternative: Build locally and push image
If Coolify's git cloning still has issues:

# Build locally
git clone https://github.com/clawdbot/clawdbot.git
cd clawdbot
docker build -t yourname/clawdbot:latest .
docker push yourname/clawdbot:latest

# In Coolify: use "Docker Image" instead of "Git Repository"
# and point to your image: yourname/clawdbot:latest


This bypasses Coolify's git handling entirely.
---

Try disabling shallow clone first - that's the simplest fix. 🦐
comonad — 17/01/2026, 03.22
patches/ doesn't exist right now, got removed in https://github.com/clawdbot/clawdbot/commit/548a32c8d4a1b9c7505ec85668a05b1f0985e3aa . try checking out commit 3567dc4a4, I've got the docker image building from there
Krill 🦐:lobster:
APP
 — 17/01/2026, 03.23
You're right! The patches/ folder was partially cleaned up (one patch was removed in b7ba94f0c), and the Dockerfile still references it but the folder might be missing in certain clones.

.comonad's suggestion is solid:

In Coolify, set the Git branch/tag to: 3567dc4a4

That commit still has the patches/ folder intact, so the Dockerfile will build correctly.

---

Better long-term fix
The Dockerfile should be updated to conditionally copy patches only if they exist. But for now, using an older commit works.

To make this permanent:
Fork the repo
Update the Dockerfile to remove COPY patches ./patches if the folder is empty/missing
Point Coolify to your fork

Or just wait for a patch release that fixes this - it's a recent regression from the pi-ai patch removal.

Thanks for the tip, .comonad! 🦐
adokce — 17/01/2026, 03.34
ok i forked the project and modified the dockerfile - i think i got it running. do i now enter terminal to my coolify server and run smth with docker command?

i think the one with weird image id (gcow...) is clawdbot
ok i forked the project and modified the dockerfile - i think i got it running. do i now enter terminal to my coolify server and run smth with docker command?

i think the one with weird image id (gcow...) is clawdbot

root@ubuntu-4gb-nbg1-1:~# docker ps
CONTAINER ID   IMAGE                                                               COMMAND                  CREATED         STATUS                   PORTS                                                                                                                                                                NAMES
440a4655f1e8   gcowksss0c0s00ckoosck8oo:7aaf019d983ab5896bfc22b40283e939c818445f   "docker-entrypoint.s…"   3 minutes ago   Up 1 second              0.0.0.0:18789->18789/tcp, [::]:18789->18789/tcp                                                                                                                      gcowksss0c0s00ckoosck8oo-022414477593
...

@Krill 🦐 
Krill 🦐:lobster:
APP
 — 17/01/2026, 03.35
Great! Yes, that's Clawdbot running! The container is up on port 18789.

Now you need to complete onboarding to configure Telegram, MiniMax, and Z.AI. Run this on your server:

docker exec -it gcowksss0c0s00ckoosck8oo-022414477593 pnpm clawdbot onboard


During onboarding:

Workspace → /home/node/clawd (default)
Model/auth → 
Add MiniMax API key (MINIMAX_API_KEY)
Add Z.AI API key (ZAI_API_KEY)
Set default to MiniMax M2.1
Gateway settings → defaults are fine (port 18789)
Telegram → enter your bot token from @BotFather
Daemon → you can skip this since Coolify manages the container

After onboarding completes:

The Control UI will be at http://YOUR_IP:18789/
You'll need to authenticate with the token shown in the onboarding output
Telegram will start polling immediately (no HTTPS needed)

Quick test:

# Check if gateway is responding
curl http://localhost:18789/health


If you see JSON output, it's working! Then open the URL in your browser and paste the token. 🦐
adokce — 17/01/2026, 03.37
now my docker image is constantly restarting for some reason @Krill 🦐 
Krill 🦐:lobster:
APP
 — 17/01/2026, 03.39
Let's see what's causing the crash. Check the logs:

docker logs --tail 50 gcowksss0c0s00ckoosck8oo-022414477593


Or follow the logs in real-time:

docker logs -f gcowksss0c0s00ckoosck8oo-022414477593


Common causes for restart loops:

Port already in use - Something else on port 18789
Bad config - Onboarding wrote invalid JSON5
Missing permissions - Volume mounts not set up correctly
OOM killed - Running out of memory

Quick debug commands:

# Check if the container is actually crashing
docker ps -a | grep gcow

# See exit code
docker inspect gcowksss0c0s00ckoosck8oo-022414477593 --format='{{.State.ExitCode}}'

# Check resource usage
docker stats


Paste the log output here and I'll help debug! 🦐
adokce — 17/01/2026, 03.53
it just keeps on restarting

root@ubuntu-4gb-nbg1-1:~# docker ps
CONTAINER ID   IMAGE                                                               COMMAND                  CREATED         STATUS                          PORTS                                                                                                                                                                NAMES
240c1963e7c2   gcowksss0c0s00ckoosck8oo:7aaf019d983ab5896bfc22b40283e939c818445f   "docker-entrypoint.s…"   6 minutes ago   Restarting (1) 54 seconds ago                                                                                                                                                                        gcowksss0c0s00ckoosck8oo-024018025727
root@ubuntu-4gb-nbg1-1:~# docker logs --tail 50 gcowksss0c0s00ckoosck8oo-024018025727
  agent             Run an agent turn via the Gateway (use --local for embedded)
...
  help              display help for command

Examples:
  clawdbot channels login --verbose
  ...
  clawdbot gateway ...
    Gateway control via WebSocket.


root@ubuntu-4gb-nbg1-1:~# docker exec -it gcowksss0c0s00ckoosck8oo-024018025727 py.
Error response from daemon: Container 240c1963e7c2ca1d8526fbf76b4a61da53fb68d3cfcc4e3bb81844d616abeafe is restarting, wait until the container is running18025727 pnpm clawdbot onboard
Krill 🦐:lobster:
APP
 — 17/01/2026, 03.53
The help output is odd - that shouldn't appear at startup. Let's debug this properly:

Check the entrypoint and actual startup:


docker inspect gcowksss0c0s00ckoosck8oo-024018025727 --format='{{.Config.Entrypoint}}'
docker inspect gcowksss0c0s00ckoosck8oo-024018025727 --format='{{.Config.Cmd}}'


Try running the container with a shell to see what's happening:


docker run --rm -it gcowksss0c0s00ckoosck8oo:7aaf019d983ab5896bfc22b40283e939c818445f ls -la /app/dist/


Does dist/index.js exist? If not, the build didn't complete.
Check if there's an entrypoint script:


docker run --rm -it gcowksss0c0s00ckoosck8oo:7aaf019d983ab5896bfc22b40283e939c818445f cat /docker-entrypoint.sh 2>/dev/null || echo "No entrypoint script"


---

Quick fix attempt - run node directly:

docker run --rm -p 18789:18789 gcowksss0c0s00ckoosck8oo:7aaf019d983ab5896bfc22b40283e939c818445f node dist/index.js


What error do you see? 🦐
adokce — 17/01/2026, 05.26
"docker run --rm -p 18789:18789 gcowksss0c0s00ckoosck8oo:7aaf019d983ab5896bfc22b40283e939c818445f node dist/index.js" - this works, i did the "onboard" but the docker service is still crashing and restarting every minute or so
Krill 🦐:lobster:
APP
 — 17/01/2026, 05.27
Based on the docs and common issues, here's what to check for a Docker crash/restart loop:

Most likely causes:

Incomplete onboard - The onboard command needs to complete fully. Check if ~/.clawdbot/clawdbot.json exists and has valid config.

Missing environment variables - For a containerized setup, you need:
docker run -e CLAWDBOT_GATEWAY_TOKEN=your-token \
           -v ~/.clawdbot:/home/node/.clawdbot \
           -v ~/clawd:/home/node/clawd \
           --rm -p 18789:18789 \
           clawdbot:local node dist/index.js

Check the actual error - Run without -d to see the crash:
   docker run --rm -p 18789:18789 <image> node dist/index.js
   


Port already in use - Make sure nothing else is on 18789.

Auth config issue - After onboard, verify:
cat ~/.clawdbot/clawdbot.json | head -50

Quick diagnostic:
# Check if gateway logs show the crash reason
docker logs <container_name_or_id>
# Or run interactively to see errors
docker run -it --rm -p 18789:18789 <image> /bin/bash
# Then manually: node dist/index.js


The official Docker approach uses docker-setup.sh which handles the config/workspace binding properly. If you built your own image or used a prebuilt one, make sure the volumes are mounted correctly so config persists.

What specific error do you see when it crashes? That'll pinpoint the issue.
adokce — 17/01/2026, 05.31
well, i'll stop here. maybe i try to set it up again tomorrow
Krill 🦐:lobster:
APP
 — 17/01/2026, 05.32
No worries! 🦐 Take a break — container deployment can be tricky.

When you're ready to try again, here's the quick checklist:

Run onboard first inside the container to generate config
Mount the volumes (~/.clawdbot and ~/clawd) so config persists
Check logs before asking — docker logs <container> or run without -d to see errors live

Drop back in #help when you're stuck. Happy to help! 🦐
adokce — 19/01/2026, 17.17
i just realized - i may not be understading clawdbot completely. please explain to me how it's meant to be used and why do people often mention tailscale? My guess is that the mainstream way to run clawdbot is to have a dedicated mac mini for it. then tailscale is used for what?
Krill 🦐:lobster:
APP
 — 19/01/2026, 17.17
Great question! Let me clarify how Clawdbot works and the Tailscale connection.

How Clawdbot works:
Clawdbot is a personal AI assistant that lives on a server (your machine or VPS) and connects to messaging platforms. You talk to it through Discord, WhatsApp, Telegram, etc., and it can actually do things — send messages, manage calendars, control devices, etc. It's not just a chatbot you query; it's an agent that can act on your behalf.

Mac Mini vs VPS:
Mac Mini is popular (especially Apple Silicon) because it's quiet, efficient, and stays on 24/7. But Linux VPS deployments are just as common — that's how I'm running right now! You can run it on any Linux machine, including containerized setups.

Why Tailscale?
Tailscale creates a secure private network between your devices. People mention it because:
Secure remote access — access your Clawdbot from anywhere without exposing ports
Device connectivity — connect phones/laptops to your home server
Simple networking — no complex firewall config needed

Think of it as: your Clawdbot lives on a server somewhere, Tailscale makes it feel like all your devices are on the same private network, even when you're away from home.

For Coolify deployment:
Most people just run the setup script in a custom Docker container or use a "Docker Run" template in Coolify. There's no official image yet, but it's straightforward to containerize yourself.

Does that clear things up? 🦐
adokce — 19/01/2026, 17.20
what do people mean when they say that they made clawdbot "run as a node"?
Krill 🦐:lobster:
APP
 — 19/01/2026, 17.21
Good follow-up! This is a key Clawdbot concept.

The "node" architecture:

Clawdbot has two main components:

Gateway — The central brain, manages config, connections, and orchestrates everything. This is what runs clawdbot gateway.

Nodes — Separate agent instances that connect to the gateway and do the actual work (executing tasks, running agents, etc.)

Why run as a node?

Split workloads — Gateway on one machine (e.g., cloud VPS), node on another (e.g., Mac Mini at home with better hardware)
Resource distribution — Offload heavy agent work to a dedicated machine
Geographic distribution — Node could be anywhere, connected via Tailscale or directly

What it looks like in practice:
# On your VPS (gateway)
clawdbot gateway

# On your Mac Mini (node)
clawdbot node connect --url "https://your-gateway:4000"


The node authenticates and registers itself. The gateway then routes agent work to that node when configured.

So when someone says "I run as a node," they mean they're running a Clawdbot agent instance that connects to someone else's gateway (or their own remote gateway).

Makes sense? 🦐