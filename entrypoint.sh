#!/bin/bash
set -e

# Start gateway (allow unconfigured for initial setup)
exec clawdbot gateway --allow-unconfigured
