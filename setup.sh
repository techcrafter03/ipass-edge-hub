#!/usr/bin/env bash
# =============================================================================
# setup.sh — iPaaS Edge Monitoring Hub — One-Script Deployment
# Deploys the full monitoring agent in under 10 minutes on any Linux system
# =============================================================================

set -euo pipefail

echo "============================================"
echo "  iPaaS Edge Monitoring Hub — Setup"
echo "  Deploying on: $(hostname) — $(uname -s)"
echo "============================================"

# --- Check dependencies ------------------------------------------------------
echo "[1/6] Checking dependencies..."
for cmd in gcc curl sqlite3 systemctl bc; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Installing $cmd..."
        sudo apt-get install -y "$cmd" 2>/dev/null || \
        sudo yum install -y "$cmd" 2>/dev/null || \
        echo "WARNING: Could not install $cmd automatically. Install manually."
    fi
done
echo "✓ Dependencies ready"

# --- Create directory structure -----------------------------------------------
echo "[2/6] Creating directory structure..."
sudo mkdir -p /var/log/ipass
sudo chmod 755 /var/log/ipass
mkdir -p bin config
echo "✓ Directories created"

# --- Compile C engine ---------------------------------------------------------
echo "[3/6] Compiling C engine..."
gcc -Wall -Wextra -o bin/log_reader src/log_reader.c
chmod +x bin/log_reader
echo "✓ C engine compiled"

# --- Configure webhook --------------------------------------------------------
echo "[4/6] Configuring webhook..."
if [ ! -f config/webhook.conf ]; then
    read -rp "Enter your Discord Webhook URL: " webhook_url
    echo "DISCORD_WEBHOOK_URL=\"$webhook_url\"" > config/webhook.conf
    chmod 600 config/webhook.conf
    echo "✓ Webhook configured"
else
    echo "✓ Webhook config already exists"
fi

# --- Make scripts executable -------------------------------------------------
echo "[5/6] Setting permissions..."
chmod +x scripts/monitor.sh
echo "✓ Permissions set"

# --- Install systemd timer ---------------------------------------------------
echo "[6/6] Installing systemd automation..."
sudo cp systemd/ipass-monitor.service /etc/systemd/system/
sudo cp systemd/ipass-monitor.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ipass-monitor.timer
echo "✓ systemd timer active — monitoring every 5 minutes"

echo ""
echo "============================================"
echo "  ✅ iPaaS Edge Hub deployed successfully"
echo "  Monitoring: $(hostname)"
echo "  Logs: /var/log/ipass/monitor.log"
echo "  Status: systemctl status ipass-monitor.timer"
echo "============================================"
