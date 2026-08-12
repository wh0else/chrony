FROM alpine:edge

# chrony    - chronyd + chronyc
# tzdata    - so TZ env var actually does something
# tini      - proper PID 1 / signal handling & zombie reaping
# bash      - entrypoint.sh uses bash features
RUN set -eu; \
    apk update; \
    apk upgrade; \
    apk add --no-cache \
        chrony \
        tzdata \
        tini \
        bash; \
    # Alpine's chrony package doesn't always pre-create the service account
    { getent group chrony >/dev/null || addgroup -S chrony; }; \
    { id -u chrony >/dev/null 2>&1 || adduser -S chrony -G chrony; }; \
    rm -f /etc/chrony/chrony.conf; \
    rm -rf /tmp/* /var/cache/apk/*

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 123/udp

# Default extra directives appended to the generated config; override per-container if needed
ENV NTP_DIRECTIVES="ratelimit,rtcsync"

# chrony.conf, the drift file, and the runtime socket dir are all generated/written
# at container startup rather than baked in or bind-mounted
VOLUME /etc/chrony /run/chrony /var/lib/chrony

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD chronyc -n tracking || exit 1

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
