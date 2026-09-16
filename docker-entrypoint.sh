#!/bin/bash
#
# A helper script for ENTRYPOINT.

set -e

[[ ${DEBUG} == true ]] && set -x

source /usr/bin/logrotate.d/logrotate.sh
source /usr/bin/logrotate.d/logrotateConf.sh

resetConfigurationFile

if [ -n "${DELAYED_START}" ]; then
  sleep ${DELAYED_START}
fi

#Create Logrotate Conf
source /usr/bin/logrotate.d/logrotateCreateConf.sh

cat /usr/bin/logrotate.d/logrotate.conf

# ----- Crontab Generation ------

logrotate_parameters=""

if [ -n "${LOGROTATE_PARAMETERS}" ]; then
  logrotate_parameters="-"${LOGROTATE_PARAMETERS}
fi

logrotate_cronlog=""

if [ -n "${LOGROTATE_LOGFILE}" ] && [ -z "${SYSLOGGER}" ]; then
  logrotate_cronlog=" 2>&1 | tee -a "${LOGROTATE_LOGFILE}
else
  if [ -n "${SYSLOGGER}" ]; then
    logrotate_cronlog=" 2>&1 | "${syslogger_command}
  fi
fi

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
    *)
      logrotate_croninterval="1 0 0 * * *"
    ;;
  esac
fi

if [ -n "${LOGROTATE_CRONSCHEDULE}" ]; then
  logrotate_croninterval=${LOGROTATE_CRONSCHEDULE}
fi

logrotate_cron_timetable="/usr/sbin/logrotate ${logrotate_parameters} --state=${logrotate_logstatus} /usr/bin/logrotate.d/logrotate.conf ${logrotate_cronlog}"

# ----- Cron Start ------

if [ "$1" = 'cron' ]; then
  # supercronic reads 6 fields as "min hour dom month dow year", while go-cron
  # style schedules use "sec min hour dom month dow": append a year field so
  # existing LOGROTATE_CRONSCHEDULE values keep their meaning.
  read -ra cron_fields <<< "${logrotate_croninterval}"
  if [[ ${logrotate_croninterval} != @* ]] && [ ${#cron_fields[@]} -eq 6 ]; then
    logrotate_croninterval="${logrotate_croninterval} *"
  fi

  logrotate_cron_command="${logrotate_cron_timetable}"
  if [ ${logrotate_autoupdate} = "true" ]; then
    logrotate_cron_command="/usr/bin/logrotate.d/update-logrotate.sh; ${logrotate_cron_timetable}"
  fi

  echo "${logrotate_croninterval} /bin/bash -c \"${logrotate_cron_command}\"" > /usr/bin/logrotate.d/crontab
  exec /usr/bin/supercronic /usr/bin/logrotate.d/crontab
fi

#-----------------------

exec "$@"
