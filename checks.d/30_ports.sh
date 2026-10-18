#!/usr/bin/env bash
# CHECK : ports
# DESC  : Detects new listening TCP ports against a baseline. New port reachable
#         from the network = CRIT, new loopback-only port = WARN.
#         Acknowledge a change with: rm state/ports.baseline
# OUTPUT: STATUS|summary
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/state"
BASE="$STATE/ports.baseline"
mkdir -p "$STATE"

if ! command -v ss >/dev/null 2>&1; then
    echo "ERROR|ss not available (install iproute2)"; exit 0
fi

snapshot() {
    ss -H -tln 2>/dev/null | awk '{
        a=$4; p=a; sub(/.*:/,"",p)
        s=(a ~ /^127\./ || a ~ /^\[::1\]/) ? "local" : "external"
        print "tcp:" p ":" s
    }' | sort -u
}

current="$(snapshot)"
n=0
if [ -n "$current" ]; then n=$(printf '%s\n' "$current" | wc -l); fi

if [ ! -f "$BASE" ]; then
    printf '%s\n' "$current" > "$BASE"
    echo "OK|baseline created, $n listening TCP ports tracked"; exit 0
fi

new_lines="$(comm -13 <(sort "$BASE") <(printf '%s\n' "$current" | sort))"
ext="$(printf '%s\n' "$new_lines" | grep ':external$' | cut -d: -f2 | sort -un | tr '\n' ' ' || true)"
loc="$(printf '%s\n' "$new_lines" | grep ':local$' | cut -d: -f2 | sort -un | tr '\n' ' ' || true)"

if [ -n "$ext" ]; then
    echo "CRIT|new network-reachable TCP port(s): $ext- acknowledge with: rm state/ports.baseline"
elif [ -n "$loc" ]; then
    echo "WARN|new loopback-only TCP port(s): $loc- acknowledge with: rm state/ports.baseline"
else
    echo "OK|$n listening TCP ports unchanged"
fi
