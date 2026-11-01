#!/usr/bin/env bash
# CHECK : users
# DESC  : Detects extra UID 0 accounts, new login accounts and new admin
#         (sudo/wheel/admin) members against a baseline.
#         Acknowledge a change with: rm state/users.baseline
# OUTPUT: STATUS|summary
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/state"
BASE="$STATE/users.baseline"
mkdir -p "$STATE"

uid0="$(awk -F: '$3==0 && $1!="root" {printf "%s ", $1}' /etc/passwd)"
if [ -n "$uid0" ]; then
    echo "CRIT|extra UID 0 account(s): $uid0"; exit 0
fi

snapshot() {
    {
        awk -F: '$7 != "" && $7 !~ /(nologin|false)$/ {print "user:" $1 ":" $3 ":" $7}' /etc/passwd
        local g m
        for g in sudo wheel admin; do
            for m in $(getent group "$g" | cut -d: -f4 | tr ',' ' '); do
                echo "admin:$g:$m"
            done
        done
    } | sort
}

current="$(snapshot)"
n=0
if [ -n "$current" ]; then n=$(printf '%s\n' "$current" | wc -l); fi

if [ ! -f "$BASE" ]; then
    printf '%s\n' "$current" > "$BASE"
    echo "OK|baseline created, $n accounts/memberships tracked"; exit 0
fi

new_lines="$(comm -13 <(sort "$BASE") <(printf '%s\n' "$current" | sort))"
new_admin="$(printf '%s\n' "$new_lines" | grep '^admin:' | cut -d: -f2- | tr '\n' ' ' || true)"
new_users="$(printf '%s\n' "$new_lines" | grep '^user:' | cut -d: -f2 | tr '\n' ' ' || true)"

if [ -n "$new_admin" ]; then
    echo "CRIT|new admin group member(s): $new_admin- acknowledge with: rm state/users.baseline"
elif [ -n "$new_users" ]; then
    echo "WARN|new login account(s): $new_users- acknowledge with: rm state/users.baseline"
else
    echo "OK|$n accounts/memberships unchanged"
fi
