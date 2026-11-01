#!/usr/bin/env bash
# CHECK : cron_systemd
# DESC  : Detects new/changed cron and systemd unit files against a baseline.
#         WARN for any change, CRIT if the content looks malicious.
#         Acknowledge a change with: rm state/cron_systemd.baseline
# OUTPUT: STATUS|summary
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/state"
BASE="$STATE/cron_systemd.baseline"
mkdir -p "$STATE"

PATTERN='curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh|/dev/tcp/|nc[[:space:]]+.*-e|base64[[:space:]]+-d|/tmp/|/dev/shm/'

list_files() {
    if [ -f /etc/crontab ]; then echo /etc/crontab; fi
    find /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /var/spool/cron \
        -maxdepth 2 -type f 2>/dev/null
    find /etc/systemd/system -maxdepth 2 -type f \( -name '*.service' -o -name '*.timer' -o -name '*.conf' \) 2>/dev/null
    find /home/*/.config/systemd/user /root/.config/systemd/user -maxdepth 1 -type f 2>/dev/null
}

snapshot() {
    {
        list_files | sort -u | while IFS= read -r f; do
            if [ -r "$f" ]; then printf '%s %s\n' "$f" "$(sha256sum < "$f" | cut -c1-16)"; fi
        done
        printf 'crontab:%s %s\n' "$(id -un)" "$(crontab -l 2>/dev/null | sha256sum | cut -c1-16)"
    } | sort
}

is_suspicious() {
    case "$1" in
        crontab:*) crontab -l 2>/dev/null | grep -Eq "$PATTERN" ;;
        *)         grep -Eq "$PATTERN" "$1" 2>/dev/null ;;
    esac
}

current="$(snapshot)"
n=$(printf '%s\n' "$current" | grep -c . || true)

if [ ! -f "$BASE" ]; then
    printf '%s\n' "$current" > "$BASE"
    echo "OK|baseline created, $n cron/systemd entries tracked"; exit 0
fi

new_lines="$(comm -13 <(sort "$BASE") <(printf '%s\n' "$current" | sort))"
paths="$(printf '%s\n' "$new_lines" | awk 'NF{print $1}' | sort -u)"

if [ -z "$paths" ]; then
    echo "OK|$n cron/systemd entries unchanged"; exit 0
fi

bad=""; list=""
for p in $paths; do
    list+="$p "
    if is_suspicious "$p"; then bad+="$p "; fi
done

if [ -n "$bad" ]; then
    echo "CRIT|suspicious content in new/changed: $bad- acknowledge with: rm state/cron_systemd.baseline"
else
    echo "WARN|new/changed cron/systemd file(s): $list- acknowledge with: rm state/cron_systemd.baseline"
fi
