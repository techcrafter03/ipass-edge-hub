#!/usr/bin/env bash
# =============================================================================
# setup.sh — iPaaS Edge Monitoring Hub — One-Script Deployment
# Deploys the full monitoring agent (checks, alerts, dashboard) in under
# 10 minutes on any Linux system. Zero external dependencies beyond the ones
# this script installs.
# =============================================================================

set -euo pipefail

echo "============================================"
echo "  iPaaS Edge Monitoring Hub — Setup"
echo "  Deploying on: $(hostname) — $(uname -s)"
echo "============================================"

# --- Check dependencies ------------------------------------------------------
echo "[1/7] Checking dependencies..."
for cmd in gcc curl sqlite3 systemctl bc python3; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Installing $cmd..."
        sudo apt-get install -y "$cmd" 2>/dev/null || \
        sudo yum install -y "$cmd" 2>/dev/null || \
        echo "WARNING: Could not install $cmd automatically. Install manually."
    fi
done
echo "✓ Dependencies ready"

# --- Create directory structure -----------------------------------------------
echo "[2/7] Creating directory structure..."
sudo mkdir -p /var/log/ipass
sudo chown "$(whoami):$(whoami)" /var/log/ipass
sudo chmod 755 /var/log/ipass
mkdir -p bin config state dashboard
echo "✓ Directories created"

# --- Compile C engine ---------------------------------------------------------
echo "[3/7] Compiling C engine..."
gcc -Wall -Wextra -o bin/log_reader src/log_reader.c
chmod +x bin/log_reader
echo "✓ C engine compiled"

# --- Configure webhook(s) ------------------------------------------------------
echo "[4/7] Configuring webhook(s)..."
if [ ! -f config/webhook.conf ]; then
    read -rp "Enter your Discord Webhook URL (leave blank to skip): " discord_url
    read -rp "Enter your Slack Webhook URL (leave blank to skip): " slack_url
    {
        [ -n "$discord_url" ] && echo "DISCORD_WEBHOOK_URL=\"$discord_url\""
        [ -n "$slack_url" ] && echo "SLACK_WEBHOOK_URL=\"$slack_url\""
    } > config/webhook.conf
    chmod 600 config/webhook.conf
    echo "✓ Webhook(s) configured"
else
    echo "✓ Webhook config already exists"
fi

# --- Configure thresholds ------------------------------------------------------
echo "[5/7] Setting up thresholds config..."
if [ ! -f config/ipass.conf ]; then
    cat > config/ipass.conf <<'EOF'
# iPaaS Edge Monitoring Hub — settings (safe to commit; no secrets here)
TEMP_WARN=80.0
RAM_WARN=85.0
# LOG_FILE=/var/log/ipass/monitor.log

# --- checks.d thresholds (override the in-script defaults) ---
SSH_FAIL_WARN=5
SSH_FAIL_CRIT=20
SSH_TAKEOVER_FAILS=5
# TMP_PROC_IGNORE='regex-to-whitelist-known-processes'
# LOG_TAMPER_FILES='/var/log/wtmp /var/log/btmp /var/log/auth.log /var/log/syslog'
EOF
    echo "✓ Default thresholds written to config/ipass.conf (edit anytime, no restart needed)"
else
    echo "✓ Thresholds config already exists"
fi

# --- Make scripts executable ---------------------------------------------------
echo "[6/7] Setting permissions..."
chmod +x scripts/monitor.sh scripts/dashboard.sh scripts/checks.sh scripts/webhook.sh
chmod +x checks.d/*.sh
echo "✓ Permissions set"

# --- Install systemd timer ------------------------------------------------------
echo "[7/7] Installing systemd automation..."
sudo cp systemd/ipass-monitor.service /etc/systemd/system/
sudo cp systemd/ipass-monitor.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ipass-monitor.timer

echo "============================================"
echo "✓ Setup complete."
echo "  - Checks run every 5 minutes via systemd timer"
echo "  - Dashboard snapshot regenerates on each run: ./dashboard/status.json"
echo "  - View the dashboard: cd dashboard && python3 -m http.server 8080 --bind 127.0.0.1"
echo "    then (from your own machine): ssh -L 8080:localhost:8080 $(whoami)@$(hostname -I | awk '{print $1}')"
echo "  - Logs: /var/log/ipass/monitor.log"
echo "============================================"
