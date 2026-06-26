#!/usr/bin/env bash
# =============================================================================
# monitor.sh — iPaaS Edge Monitoring Hub Master Wrapper
# Author      : Spidey
# Description : Reads log sizes via C engine, collects hardware stats,
#               builds a JSON payload, and fires it to Discord webhook.
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly BINARY="$PROJECT_DIR/bin/log_reader"
readonly LOG_FILE="/var/log/ipass/monitor.log"
readonly CONFIG_FILE="$PROJECT_DIR/config/webhook.conf"

# --- Logging Function --------------------------------------------------------
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] [$SCRIPT_NAME] $message" | tee -a "$LOG_FILE"
}

# --- Cleanup / Signal Trap ---------------------------------------------------
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "Script exited unexpectedly with code: $exit_code"
    else
        log "INFO" "Script completed successfully."
    fi
}
trap cleanup EXIT
trap 'log "WARN" "Interrupted by user (SIGINT)."; exit 130' INT
trap 'log "WARN" "Terminated (SIGTERM)."; exit 143' TERM

# --- Pre-flight Checks -------------------------------------------------------
log "INFO" "=== iPaaS Monitor starting ==="
log "INFO" "Running as user: $(whoami) on $(hostname)"

if [ ! -x "$BINARY" ]; then
    log "ERROR" "Binary not found or not executable: $BINARY"
    exit 1
fi

if [ ! -r "$CONFIG_FILE" ]; then
    log "ERROR" "Config file not found or not readable: $CONFIG_FILE"
    exit 1
fi

# Load webhook URL from config
# shellcheck source=/dev/null
source "$CONFIG_FILE"

if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
    log "ERROR" "DISCORD_WEBHOOK_URL is not set in $CONFIG_FILE"
    exit 1
fi

# --- Run the C Engine --------------------------------------------------------
log "INFO" "Launching C log-reader engine..."
engine_output="$("$BINARY")"
log "INFO" "C engine completed successfully."

# --- Collect Hardware Stats --------------------------------------------------
log "INFO" "Collecting hardware statistics..."

# CPU Temperature (in millidegrees → convert to Celsius)
cpu_temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
cpu_temp_c=$(awk "BEGIN {printf \"%.1f\", $cpu_temp_raw/1000}")

# Memory Usage from /proc/meminfo (values are in KB)
mem_total=$(grep MemTotal  /proc/meminfo | awk '{print $2}')
mem_avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
mem_used=$((mem_total - mem_avail))
mem_percent=$(awk "BEGIN {printf \"%.1f\", $mem_used*100/$mem_total}")
mem_used_mb=$(awk "BEGIN {printf \"%.0f\", $mem_used/1024}")
mem_total_mb=$(awk "BEGIN {printf \"%.0f\", $mem_total/1024}")

# Disk Usage for root partition
disk_percent=$(df / | tail -1 | awk '{print $5}')
disk_used=$(df -h / | tail -1 | awk '{print $3}')
disk_total=$(df -h / | tail -1 | awk '{print $2}')

# System Load Average (1min, 5min, 15min)
load_avg=$(awk '{print $1", "$2", "$3}' /proc/loadavg)

# Uptime
uptime_str=$(uptime -p | sed 's/up //')

# ISO 8601 timestamp for Discord embed
timestamp_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

log "INFO" "CPU: ${cpu_temp_c}C | RAM: ${mem_percent}% | Disk: ${disk_percent} | Load: ${load_avg}"

# --- Build JSON Payload ------------------------------------------------------
log "INFO" "Building Discord JSON payload..."

json_payload=$(cat <<EOF
{
  "username": "iPaaS Edge Hub",
  "avatar_url": "https://www.raspberrypi.com/app/uploads/2022/02/COLOUR-Raspberry-Pi-Symbol-Registered.png",
  "embeds": [{
    "title": "📊 Edge Monitor Report — $(hostname)",
    "description": "Live snapshot from Raspberry Pi 3 monitoring hub.",
    "color": 5763719,
    "fields": [
      {
        "name": "🌡️ CPU Temperature",
        "value": "${cpu_temp_c}°C",
        "inline": true
      },
      {
        "name": "💾 Memory Usage",
        "value": "${mem_used_mb} MB / ${mem_total_mb} MB (${mem_percent}%)",
        "inline": true
      },
      {
        "name": "💿 Disk Usage",
        "value": "${disk_used} / ${disk_total} (${disk_percent})",
        "inline": true
      },
      {
        "name": "⚡ Load Average",
        "value": "${load_avg}",
        "inline": true
      },
      {
        "name": "⏱️ Uptime",
        "value": "${uptime_str}",
        "inline": true
      },
      {
        "name": "👤 Run By",
        "value": "$(whoami)",
        "inline": true
      }
    ],
    "footer": {
      "text": "iPaaS Mini Edge Hub • Raspberry Pi 3 • Raspbian Bookworm 64-bit"
    },
    "timestamp": "${timestamp_iso}"
  }]
}
EOF
)

# --- Send to Discord ----------------------------------------------------------
log "INFO" "Sending payload to Discord webhook..."

http_status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    "$DISCORD_WEBHOOK_URL")

if [ "$http_status" -eq 204 ]; then
    log "INFO" "Discord notification sent successfully. HTTP: $http_status"
else
    log "ERROR" "Discord webhook failed. HTTP status: $http_status"
    exit 1
fi

# --- Print Engine Report to Terminal -----------------------------------------
echo ""
echo "$engine_output"
echo ""

log "INFO" "All tasks complete. Log: $LOG_FILE"