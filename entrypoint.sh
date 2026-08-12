#!/usr/bin/env bash
set -euo pipefail

: "${NTP_SERVERS:=pool.ntp.org}"
: "${NTP_DIRECTIVES:=ratelimit,rtcsync}"
: "${ENABLE_SYSCLK:=false}"
: "${NOCLIENTLOG:=false}"
: "${LOG_LEVEL:=}"

# --- Timezone ----------------------------------------------------------
if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "$TZ" > /etc/timezone
fi

mkdir -p /etc/chrony /run/chrony /var/lib/chrony
chown -R chrony:chrony /run/chrony /var/lib/chrony

# --- Generate chrony.conf from env vars ---------------------------------
{
    # NTP_SERVERS is a comma-delimited list, no spaces (matches dockur/chrony's own convention)
    IFS=',' read -ra SERVERS <<< "$NTP_SERVERS"
    for s in "${SERVERS[@]}"; do
        [ -z "$s" ] && continue
        echo "server ${s} iburst"
    done

    IFS=',' read -ra DIRECTIVES <<< "$NTP_DIRECTIVES"
    for d in "${DIRECTIVES[@]}"; do
        [ -n "$d" ] && echo "$d"
    done

    [ "$NOCLIENTLOG" = "true" ] && echo "noclientlog"

    echo "driftfile /var/lib/chrony/chrony.drift"
    echo "logdir /var/log/chrony"
} > /etc/chrony/chrony.conf

# --- Assemble chronyd flags ----------------------------------------------
CHRONYD_OPTS=(-d -f /etc/chrony/chrony.conf -u chrony)

# chronyd only gets clock-control privileges if you opted in AND granted SYS_TIME;
# otherwise it stays read-only with respect to the host/container clock (-x)
if [ "$ENABLE_SYSCLK" != "true" ]; then
    CHRONYD_OPTS+=(-x)
fi

if [ -n "$LOG_LEVEL" ]; then
    CHRONYD_OPTS+=(-L "$LOG_LEVEL")
fi

exec chronyd "${CHRONYD_OPTS[@]}"
