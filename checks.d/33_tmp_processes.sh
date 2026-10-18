#!/usr/bin/env bash
# CHECK : tmp_processes
# DESC  : Flags processes running from /tmp, /var/tmp or /dev/shm (typical
#         malware staging), including binaries deleted after launch.
#         Whitelist legitimate ones with TMP_PROC_IGNORE='regex'.
# OUTPUT: STATUS|summary
set -u
export LC_ALL=C
IGNORE="${TMP_PROC_IGNORE:-}"

hits="$( {
    ps -eo pid=,user=,args= 2>/dev/null | awk '
        {
            p = ""
            if ($3 ~ /^\/(tmp|var\/tmp|dev\/shm)\//) p = $3
            else if ($4 ~ /^\/(tmp|var\/tmp|dev\/shm)\//) p = $4
            if (p != "") print $1 ":" p
        }'
    for e in /proc/[0-9]*/exe; do
        t="$(readlink "$e" 2>/dev/null || true)"
        case "$t" in
            /tmp/*|/var/tmp/*|/dev/shm/*)
                pid="${e#/proc/}"; pid="${pid%/exe}"
                echo "$pid:$t" ;;
        esac
    done
} | sort -u )"

if [ -n "$IGNORE" ] && [ -n "$hits" ]; then
    hits="$(printf '%s\n' "$hits" | grep -Ev "$IGNORE" || true)"
fi

count=$(printf '%s\n' "$hits" | grep -c . || true)
if [ "$count" -gt 0 ]; then
    shown=$(printf '%s\n' "$hits" | head -5 | tr '\n' ' ')
    echo "CRIT|$count process(es) running from temp dirs: $shown"
else
    echo "OK|no processes running from /tmp, /var/tmp or /dev/shm"
fi
