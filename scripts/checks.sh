#!/usr/bin/env bash
# checks.sh — sourced by monitor.sh.
# Runs every executable checks.d/NN_*.sh, stores each result in check_results,
# and alerts only when a check's status CHANGES.
# Check contract: print ONE line "STATUS|summary" (OK, WARN, CRIT, ERROR), exit 0.

run_checks() {
    local db="$PROJECT_DIR/ipass_metrics.db"
    local dir="$PROJECT_DIR/checks.d"
    local f name out status summary prev color host
    host="$(hostname)"

    if [ ! -d "$dir" ]; then return 0; fi

    sqlite3 "$db" "CREATE TABLE IF NOT EXISTS check_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        host TEXT NOT NULL,
        check_name TEXT NOT NULL,
        status TEXT NOT NULL,
        summary TEXT
    );"

    for f in "$dir"/[0-9][0-9]_*.sh; do
        if [ ! -x "$f" ]; then continue; fi
        name="$(basename "$f" .sh)"
        out="$(timeout 20 "$f" 2>/dev/null | head -n 1)" || out="ERROR|check failed or timed out"
        status="${out%%|*}"
        summary="${out#*|}"
        case "$status" in
            OK|WARN|CRIT|ERROR) ;;
            *) status="ERROR"; summary="invalid output from $name" ;;
        esac
        # keep SQL and JSON safe: drop backslash, double quote, apostrophe
        summary="$(printf '%s' "$summary" | tr -d '\\"\047')"

        prev="$(sqlite3 "$db" "SELECT status FROM check_results WHERE check_name='$name' ORDER BY id DESC LIMIT 1;")"
        prev="${prev:-OK}"

        sqlite3 "$db" "INSERT INTO check_results (timestamp, host, check_name, status, summary) VALUES ('${timestamp_iso}', '${host}', '${name}', '${status}', '${summary}');"
        log "INFO" "check $name: $status - $summary"

        if [ "$status" != "$prev" ]; then
            case "$status" in
                CRIT)  color=15158332 ;;
                WARN)  color=16753920 ;;
                ERROR) color=9807270 ;;
                *)     color=5763719 ;;
            esac
            if [ "$status" = "OK" ]; then
                send_webhook "✅ RECOVERED: $name — $host" "$summary" "$color"
            else
                send_webhook "🔎 $status: $name — $host" "$summary" "$color"
            fi
            log "WARN" "check $name changed $prev -> $status (alert sent)"
        fi
    done
}
