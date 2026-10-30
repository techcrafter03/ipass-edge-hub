#!/usr/bin/env bash
# webhook.sh — sourced by monitor.sh.
# send_webhook <title> <message> [discord_color]
# Sends one alert to every configured webhook. Never aborts the caller.
send_webhook() {
    local title="$1" message="$2" color="${3:-15158332}"
    local ts payload status
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
        payload=$(cat <<EOF
{"username":"iPaaS Edge Hub","embeds":[{"title":"${title}","description":"${message}","color":${color},"footer":{"text":"iPaaS Edge Monitoring Hub • Linux"},"timestamp":"${ts}"}]}
EOF
)
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
            -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK_URL") || status=000
        log "INFO" "Discord alert HTTP: $status"
    fi

    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        payload=$(cat <<EOF
{"text":"*${title}*\n${message}"}
EOF
)
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
            -H "Content-Type: application/json" -d "$payload" "https://hooks.slack.com/services/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" "Slack alert HTTP: $status"
    fi
    return 0
}
