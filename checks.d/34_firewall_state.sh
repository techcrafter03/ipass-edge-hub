#!/usr/bin/env bash
# CHECK : firewall_state
# DESC  : Watches the host firewall: service state (any user) and, as root,
#         the ruleset itself. CRIT if a firewall that was active got stopped;
#         WARN if rules changed, no firewall is active, or the ruleset is empty.
#         Acknowledge a change with: rm state/firewall.baseline
# OUTPUT: STATUS|summary
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${IPASS_STATE_DIR:-$ROOT/state}"
BASE="$STATE/firewall.baseline"
mkdir -p "$STATE"

svc=""; any_active="no"
for u in ufw nftables firewalld netfilter-persistent; do
    st="$(systemctl is-active "$u" 2>/dev/null || true)"
    if [ -z "$st" ]; then st="unknown"; fi
    svc+="$u:$st "
    if [ "$st" = "active" ]; then any_active="yes"; fi
done

rules_hash="unreadable"; rule_count="?"
if [ "$(id -u)" -eq 0 ]; then
    dump="$( { iptables-save 2>/dev/null | sed -e 's/\[[0-9]*:[0-9]*\]//' -e '/^#/d'; nft list ruleset 2>/dev/null; } )"
    rules_hash="$(printf '%s' "$dump" | sha256sum | cut -c1-16)"
    rule_count="$(printf '%s\n' "$dump" | grep -cE '^-A |[[:space:]](accept|drop|reject)([[:space:]]|$)' || true)"
fi

if [ ! -f "$BASE" ]; then
    printf 'any_active=%s\nrules_hash=%s\n' "$any_active" "$rules_hash" > "$BASE"
fi
prev_active="$(grep '^any_active=' "$BASE" | cut -d= -f2)"
prev_hash="$(grep '^rules_hash=' "$BASE" | cut -d= -f2)"

if [ "$prev_active" = "yes" ] && [ "$any_active" = "no" ]; then
    echo "CRIT|firewall was active at baseline but is now stopped ($svc)"
elif [ "$prev_hash" != "unreadable" ] && [ "$rules_hash" != "unreadable" ] && [ "$prev_hash" != "$rules_hash" ]; then
    echo "WARN|firewall ruleset changed - acknowledge with: rm state/firewall.baseline"
elif [ "$any_active" = "no" ]; then
    echo "WARN|no host firewall service active ($svc)"
elif [ "$rule_count" = "0" ]; then
    echo "WARN|firewall running but ruleset is empty ($svc)"
else
    echo "OK|firewall active ($svc) rules=$rule_count"
fi
