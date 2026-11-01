#!/usr/bin/env bash
# CHECK : log_tamper
# DESC  : Detects log files truncated, deleted or replaced without a matching
#         logrotate rotation (attackers clearing their tracks).
#         Event-based: reports once, then tracks the new state.
# OUTPUT: STATUS|summary
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/state"
SF="$STATE/log_tamper.state"
FILES="${LOG_TAMPER_FILES:-/var/log/wtmp /var/log/btmp /var/log/auth.log /var/log/syslog}"
mkdir -p "$STATE"
now=$(date +%s)

declare -A p_ino p_size
last_run=0
if [ -f "$SF" ]; then
    while read -r path ino size; do
        if [ "$path" = "#last_run" ]; then
            last_run="$ino"
        else
            p_ino["$path"]="$ino"; p_size["$path"]="$size"
        fi
    done < "$SF"
fi

# true if a rotated sibling (.1, .1.gz, .0, -DATE) was written since last run
rotated_since() {
    local s m
    for s in "$1".1 "$1".1.gz "$1".0 "$1"-*; do
        if [ -e "$s" ]; then
            m=$(stat -c '%Y %Z' "$s" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)
            if [ "${m:-0}" -ge "$last_run" ]; then return 0; fi
        fi
    done
    return 1
}

crit=""; warn=""; tracked=0
new_state="#last_run $now"$'\n'

for f in $FILES; do
    if [ ! -e "$f" ]; then
        if [ -n "${p_ino[$f]:-}" ] && ! rotated_since "$f"; then
            crit+="$f deleted; "
        fi
        continue
    fi
    read -r ino size < <(stat -c '%i %s' "$f")
    tracked=$((tracked + 1))
    new_state+="$f $ino $size"$'\n'
    if [ -n "${p_ino[$f]:-}" ]; then
        if [ "$ino" != "${p_ino[$f]}" ]; then
            if ! rotated_since "$f"; then warn+="$f replaced without rotation; "; fi
        elif [ "$size" -lt "${p_size[$f]}" ]; then
            if ! rotated_since "$f"; then crit+="$f shrank from ${p_size[$f]} to $size bytes; "; fi
        fi
    fi
done

printf '%s' "$new_state" > "$SF"

if [ -n "$crit" ]; then
    echo "CRIT|log file shrank or vanished with no matching rotation: $crit"
elif [ -n "$warn" ]; then
    echo "WARN|$warn"
else
    echo "OK|$tracked log files tracked, no truncation"
fi
