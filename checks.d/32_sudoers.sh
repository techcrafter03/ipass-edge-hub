#!/usr/bin/env bash
# CHECK : sudoers
# DESC  : Detects changes to /etc/sudoers and /etc/sudoers.d/* (who gets root).
#         Tracks size/mtime/inode/owner; as root also content hash and a
#         NOPASSWD / !authenticate scan (CRIT).
#         Acknowledge a change with: rm state/sudoers.baseline
# OUTPUT: STATUS|summary
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/state"
BASE="$STATE/sudoers.baseline"
mkdir -p "$STATE"

snapshot() {
    local f h
    for f in /etc/sudoers /etc/sudoers.d/*; do
        if [ -f "$f" ]; then
            h="-"
            if [ -r "$f" ]; then h="$(sha256sum < "$f" | cut -c1-16)"; fi
            printf '%s %s\n' "$(stat -c '%n %s %Y %i %U' "$f")" "$h"
        fi
    done | sort
}

current="$(snapshot)"
n=$(printf '%s\n' "$current" | grep -c . || true)

if [ ! -f "$BASE" ]; then
    printf '%s\n' "$current" > "$BASE"
    echo "OK|baseline created, $n sudoers file(s) tracked"; exit 0
fi

new_lines="$(comm -13 <(sort "$BASE") <(printf '%s\n' "$current" | sort))"
paths="$(printf '%s\n' "$new_lines" | awk 'NF{print $1}' | sort -u)"

if [ -z "$paths" ]; then
    echo "OK|$n sudoers file(s) unchanged"; exit 0
fi

bad=""; list=""
for p in $paths; do
    list+="$p "
    if [ -r "$p" ] && grep -Eq 'NOPASSWD|!authenticate' "$p" 2>/dev/null; then bad+="$p "; fi
done

if [ -n "$bad" ]; then
    echo "CRIT|passwordless sudo rule in changed file(s): $bad- acknowledge with: rm state/sudoers.baseline"
else
    echo "WARN|sudoers changed: $list- acknowledge with: rm state/sudoers.baseline"
fi
