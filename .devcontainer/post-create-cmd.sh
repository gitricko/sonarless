#!/bin/bash

# Install modelrelay globally
sudo npm install modelrelay -g --prefix /usr/local/lib/modelrelay
sudo ln -sf /usr/local/lib/modelrelay/bin/modelrelay /usr/local/bin/modelrelay
sudo npm cache clean --force

echo "[post-create-cmd.sh] Starting modelrelay in the background..."
if command -v modelrelay &>/dev/null; then
  setsid /usr/local/bin/modelrelay >> /tmp/modelrelay.log 2>&1 &
else
  echo "[post-create-cmd.sh] modelrelay not found, skipping start"
fi

# Install hermes-agent
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup
npm cache clean --force
sudo rm -rf /var/lib/apt/lists/* 

# Configure hermes defaults if first run
if command -v hermes &>/dev/null && [ -d "$HOME/.hermes/sessions" ] && [ -z "$(ls -A "$HOME/.hermes/sessions")" ]; then
  echo "[post-create-cmd.sh] No sessions found, setting up default configuration for custom provider"
  hermes config set model.provider custom
  hermes config set model.base_url http://localhost:7352/v1
  hermes config set model.default auto-fastest
fi