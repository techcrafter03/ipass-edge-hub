#!/usr/bin/env bash
# CHECK : ssh_bruteforce
# DESC  : Counts failed SSH password logins in the last 10 minutes.
# OUTPUT: STATUS|summary
set -u
WARN_AT="${SSH_FAIL_WARN:-5}"
CRIT_AT="${SSH_FAIL_CRIT:-20}"

if ! command -v journalctl >/dev/null 2>&1; then
    echo "ERROR|journalctl not available"; exit 0
fi
if [ "$(id -u)" -ne 0 ] && ! id -nG | tr ' ' '\n' | grep -qxE 'systemd-journal|adm'; then
    echo "ERROR|cannot read journal (run as root or join systemd-journal group)"; exit 0
fi

fails="$(journalctl -q -u ssh -u sshd --since '10 minutes ago' 2>/dev/null | grep 'Failed password' || true)"
count=0
if [ -n "$fails" ]; then count=$(printf '%s\n' "$fails" | wc -l); fi

top=""
if [ "$count" -gt 0 ]; then
    top=$(printf '%s\n' "$fails" | grep -oE 'from [0-9a-fA-F:.]+' | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2" ("$1"x)"}')
fi

if [ "$count" -ge "$CRIT_AT" ]; then
    echo "CRIT|$count failed SSH logins in 10 min, top source $top"
elif [ "$count" -ge "$WARN_AT" ]; then
    echo "WARN|$count failed SSH logins in 10 min, top source $top"
else
    echo "OK|$count failed SSH logins in 10 min"
fi
