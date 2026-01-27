FROM node:22

# Full node image includes build tools

# Create non-root user directories
RUN mkdir -p /home/node/.clawdbot /home/node/clawd \
    && chown -R node:node /home/node

# Install clawdbot globally
RUN npm install -g clawdbot --unsafe-perm --verbose 2>&1 || (echo "npm install failed" && exit 1)

# Switch to non-root user
USER node
WORKDIR /home/node

# Copy entrypoint
COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
RUN chmod +x /home/node/entrypoint.sh

EXPOSE 18789

ENTRYPOINT ["/home/node/entrypoint.sh"]
