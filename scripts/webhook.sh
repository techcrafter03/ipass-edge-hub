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
            -H "Content-Type: application/json" -d "$payload" "https://join.slack.com/share/enQtMTI0OTE5MTEyMzU0MjQtZWNiZGEzZDE2MDI1NzdhNmZjNWU0OWFlYTQ5MDVjMWFjYzRhMDE1ZjNhODQ3ZWU2Y2IzY2MxMmQxMTk3Zjk0Nw?entry_point=default_oauth&ssb_vid=4669b6c81cd38beba126fedac34d748b&ssb_instance_id=3f80a1c1-90a4-4878-9be1-ba383abf6be0&v=4.53.276&from_desktop_app=1&from_ssb_landing=1") || status=000
        log "INFO" "Slack alert HTTP: $status"
    fi
    return 0
}
