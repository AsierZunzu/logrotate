FROM alpine:3.24
LABEL org.opencontainers.image.title="logrotate" \
      org.opencontainers.image.description="Side-car container that crawls for log files and rotates them with logrotate" \
      org.opencontainers.image.authors="Asier Zunzunegui" \
      org.opencontainers.image.source="https://github.com/AsierZunzu/logrotate" \
      org.opencontainers.image.licenses="MIT"

# logrotate package version (e.g. 3.22.0-r0)
ARG LOGROTATE_VERSION=latest

RUN apk add --no-cache \
      gzip \
      tzdata \
      bash \
      tini \
      supercronic && \
    if  [ "${LOGROTATE_VERSION}" = "latest" ]; \
      then apk add --no-cache logrotate ; \
      else apk add --no-cache "logrotate=${LOGROTATE_VERSION}" ; \
    fi && \
    mkdir -p /logrotate-status && \
    chmod 1777 /logrotate-status

# environment variable for this container
ENV LOGROTATE_OLDDIR= \
    LOGROTATE_COMPRESSION= \
    LOGROTATE_INTERVAL= \
    LOGROTATE_COPIES= \
    LOGROTATE_SIZE= \
    LOGS_DIRECTORIES= \
    LOG_FILE_ENDINGS= \
    LOGROTATE_LOGFILE= \
    LOGROTATE_CRONSCHEDULE= \
    LOGROTATE_PARAMETERS= \
    LOGROTATE_STATUSFILE=

COPY docker-entrypoint.sh /usr/bin/logrotate.d/docker-entrypoint.sh
COPY update-logrotate.sh /usr/bin/logrotate.d/update-logrotate.sh
COPY run-logrotate.sh /usr/bin/logrotate.d/run-logrotate.sh
COPY logrotate.sh /usr/bin/logrotate.d/logrotate.sh
COPY logrotateConf.sh /usr/bin/logrotate.d/logrotateConf.sh
COPY logrotateCreateConf.sh /usr/bin/logrotate.d/logrotateCreateConf.sh

# Healthy while supercronic runs, or while the entrypoint is still waiting on DELAYED_START.
# Patterns are anchored to the full command line: tini's arguments also contain the
# entrypoint path, and busybox pgrep -x compares against argv[0] including its directory.
HEALTHCHECK --interval=1m --timeout=5s \
  CMD pgrep -f '^/usr/bin/supercronic ' >/dev/null || pgrep -f '^/bin/bash /usr/bin/logrotate.d/docker-entrypoint.sh' >/dev/null || exit 1

ENTRYPOINT ["/sbin/tini","--","/usr/bin/logrotate.d/docker-entrypoint.sh"]
VOLUME ["/logrotate-status"]
CMD ["cron"]
