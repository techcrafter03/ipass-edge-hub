#!/usr/bin/env bash
# CHECK : authorized_keys
# DESC  : Detects SSH keys added to / removed from any authorized_keys file
#         (classic persistence trick). CRIT stays until acknowledged with:
#         rm state/authorized_keys.baseline
# OUTPUT: STATUS|summary
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/state"
BASE="$STATE/authorized_keys.baseline"
mkdir -p "$STATE"

snapshot() {
    local f line
    for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
        if [ -r "$f" ]; then
            grep -vE '^[[:space:]]*(#|$)' "$f" | while IFS= read -r line; do
                printf '%s %s\n' "$f" "$(printf '%s' "$line" | sha256sum | cut -c1-16)"
            done
        fi
    done | sort
}

current="$(snapshot)"
note=""
if [ "$(id -u)" -ne 0 ]; then note=" (not root: some users' files may be unreadable)"; fi
n_keys=0
if [ -n "$current" ]; then n_keys=$(printf '%s\n' "$current" | wc -l); fi

if [ ! -f "$BASE" ]; then
    printf '%s\n' "$current" > "$BASE"
    echo "OK|baseline created, $n_keys keys tracked$note"; exit 0
fi

new_lines="$(comm -13 <(sort "$BASE") <(printf '%s\n' "$current" | sort))"
gone_lines="$(comm -23 <(sort "$BASE") <(printf '%s\n' "$current" | sort))"
added=$(printf '%s\n' "$new_lines" | grep -c . || true)
removed=$(printf '%s\n' "$gone_lines" | grep -c . || true)

if [ "$added" -gt 0 ]; then
    files=$(printf '%s\n' "$new_lines" | awk 'NF{print $1}' | sort -u | tr '\n' ' ')
    echo "CRIT|$added new SSH key(s) in: $files- acknowledge with: rm state/authorized_keys.baseline"
elif [ "$removed" -gt 0 ]; then
    echo "WARN|$removed SSH key(s) removed from authorized_keys - acknowledge with: rm state/authorized_keys.baseline"
else
    echo "OK|$n_keys keys unchanged$note"
fi
