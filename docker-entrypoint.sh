#!/bin/bash
#
# A helper script for ENTRYPOINT.

set -e

[[ ${DEBUG} == true ]] && set -x

source /usr/bin/logrotate.d/logrotate.sh
source /usr/bin/logrotate.d/logrotateConf.sh

if ! validateConfiguration; then
  echo "Invalid configuration, exiting" >&2
  exit 1
fi

resetConfigurationFile

if [ -n "${DELAYED_START}" ]; then
  sleep "${DELAYED_START}"
fi

#Create Logrotate Conf
source /usr/bin/logrotate.d/logrotateCreateConf.sh

cat "${logrotate_conf_file}"

# ----- Crontab Generation ------

logrotate_croninterval="1 0 0 * * *"

if [ -n "${LOGROTATE_INTERVAL}" ]; then
  case "$LOGROTATE_INTERVAL" in
    hourly)
      logrotate_croninterval='@hourly'
    ;;
    daily)
      logrotate_croninterval='@daily'
    ;;
    weekly)
      logrotate_croninterval='@weekly'
    ;;
    monthly)
      logrotate_croninterval='@monthly'
    ;;
    yearly)
      logrotate_croninterval='@yearly'
    ;;
  esac
fi

if [ -n "${LOGROTATE_CRONSCHEDULE}" ]; then
  logrotate_croninterval=${LOGROTATE_CRONSCHEDULE}
fi

# ----- Cron Start ------

if [ "$1" = 'cron' ]; then
  # supercronic reads 6 fields as "min hour dom month dow year", while go-cron
  # style schedules use "sec min hour dom month dow": append a year field so
  # existing LOGROTATE_CRONSCHEDULE values keep their meaning.
  read -ra cron_fields <<< "${logrotate_croninterval}"
  if [[ ${logrotate_croninterval} != @* ]] && [ ${#cron_fields[@]} -eq 6 ]; then
    logrotate_croninterval="${logrotate_croninterval} *"
  fi

  echo "${logrotate_croninterval} /usr/bin/logrotate.d/run-logrotate.sh" > "${logrotate_crontab_file}"
  if ! /usr/bin/supercronic -test "${logrotate_crontab_file}"; then
    echo "Invalid cron schedule '${logrotate_croninterval}', check LOGROTATE_CRONSCHEDULE" >&2
    exit 1
  fi
  exec /usr/bin/supercronic "${logrotate_crontab_file}"
fi

#-----------------------

exec "$@"
