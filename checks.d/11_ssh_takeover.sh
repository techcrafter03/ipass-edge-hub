#!/usr/bin/env bash
# CHECK : ssh_takeover
# DESC  : Flags a successful SSH login from an IP that was failing logins
#         just before (likely brute-force success), and direct root logins.
# OUTPUT: STATUS|summary
set -u
MIN_FAILS="${SSH_TAKEOVER_FAILS:-5}"

if ! command -v journalctl >/dev/null 2>&1; then
    echo "ERROR|journalctl not available"; exit 0
fi
if [ "$(id -u)" -ne 0 ] && ! id -nG | tr ' ' '\n' | grep -qxE 'systemd-journal|adm'; then
    echo "ERROR|cannot read journal (run as root or join systemd-journal group)"; exit 0
fi

lines="$(journalctl -q -u ssh -u sshd --since '10 minutes ago' 2>/dev/null || true)"
accepted="$(printf '%s\n' "$lines" | grep 'Accepted ' || true)"
n_acc=0
if [ -n "$accepted" ]; then n_acc=$(printf '%s\n' "$accepted" | wc -l); fi

hit=""
for ip in $(printf '%s\n' "$accepted" | grep -oE 'from [0-9a-fA-F:.]+' | awk '{print $2}' | sort -u); do
    nf=$(printf '%s\n' "$lines" | grep 'Failed password' | grep -cF "from $ip " || true)
    if [ "$nf" -ge "$MIN_FAILS" ]; then hit="$ip ($nf failures, then login)"; break; fi
done
if [ -n "$hit" ]; then
    echo "CRIT|login succeeded after brute force from $hit"; exit 0
fi

root_logins=$(printf '%s\n' "$accepted" | grep -c 'for root from' || true)
if [ "$root_logins" -gt 0 ]; then
    echo "WARN|$root_logins direct root SSH login(s) in 10 min"; exit 0
fi

echo "OK|$n_acc successful SSH logins in 10 min, none suspicious"
