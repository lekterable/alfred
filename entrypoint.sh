#!/bin/bash
set -e

# Ensure gateway binds to all interfaces (required for container networking)
clawdbot config set gateway.bind lan 2>/dev/null || true

# Start gateway
exec clawdbot gateway --allow-unconfigured
