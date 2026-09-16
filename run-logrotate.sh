#!/bin/bash
#
# The cron job: refreshes the configuration when enabled and runs logrotate.
# Settings are read from the environment supercronic passes to jobs, so no
# value has to be quoted into the crontab line.

# Keep logrotate's exit status when its output is piped to tee or logger.
set -o pipefail

[[ ${DEBUG} == true ]] && set -x

source /usr/bin/logrotate.d/logrotate.sh

if [ "${logrotate_autoupdate}" = "true" ]; then
  /usr/bin/logrotate.d/update-logrotate.sh
fi

logrotate_args=()
if [ -n "${LOGROTATE_PARAMETERS}" ]; then
  logrotate_args+=("-${LOGROTATE_PARAMETERS}")
fi
logrotate_args+=("--state=${logrotate_logstatus}" /usr/bin/logrotate.d/logrotate.conf)

if [ -n "${SYSLOGGER}" ]; then
  /usr/sbin/logrotate "${logrotate_args[@]}" 2>&1 | logger "${syslogger_args[@]}"
elif [ -n "${LOGROTATE_LOGFILE}" ]; then
  /usr/sbin/logrotate "${logrotate_args[@]}" 2>&1 | tee -a "${LOGROTATE_LOGFILE}"
else
  exec /usr/sbin/logrotate "${logrotate_args[@]}"
fi
