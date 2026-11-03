#!/usr/bin/env bash
# dashboard.sh — generates a static status.json snapshot from ipass_metrics.db.
# Called by monitor.sh after run_checks. No server, no new deps.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DB="$PROJECT_DIR/ipass_metrics.db"
OUT_DIR="$PROJECT_DIR/dashboard"

mkdir -p "$OUT_DIR"

# Latest status per check
checks_json=$(sqlite3 -json "$DB" "
  SELECT check_name, status, summary, timestamp
  FROM check_results c
  WHERE id = (SELECT MAX(id) FROM check_results WHERE check_name = c.check_name)
  ORDER BY check_name;
" 2>/dev/null || echo "[]")

# Last 20 metric snapshots (CPU/RAM/disk history)
metrics_json=$(sqlite3 -json "$DB" "
  SELECT timestamp, cpu_temp, mem_percent, disk_percent, load_avg
  FROM metrics
  ORDER BY id DESC
  LIMIT 20;
" 2>/dev/null || echo "[]")

cat > "$OUT_DIR/status.json" <<EOF
{
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "host": "$(hostname)",
  "checks": $checks_json,
  "metrics": $metrics_json
}
EOF
