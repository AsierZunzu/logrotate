#!/bin/bash
#
# Helper functions for configuration and running logrotate.

# Generated files live outside the image's program directory, so the root
# filesystem can be mounted read-only with a tmpfs on /tmp.
readonly logrotate_generated_dir="/tmp/logrotate"
readonly logrotate_conf_file="${logrotate_generated_dir}/logrotate.conf"
readonly logrotate_crontab_file="${logrotate_generated_dir}/crontab"

# Resetting the default configuration file for
# repeated starts.
function resetConfigurationFile() {
  mkdir -p "${logrotate_generated_dir}"

  cat > "${logrotate_conf_file}" <<EOF
# deactivate mail
nomail

# move the log files to another directory?
${logrotate_olddir}
EOF
}

# Entries only get su when running as root (see createLogrotateConfigurationEntry).
logrotate_running_as_root=false
if [ "$(id -u)" = "0" ]; then
  logrotate_running_as_root=true
fi

# Logrotate status file handling
readonly logrotate_logstatus=${LOGROTATE_STATUSFILE:-"/logrotate-status/logrotate.status"}

logrotate_olddir=""

function resolveOldDir() {
  if [ -n "${LOGROTATE_OLDDIR}" ]; then
    logrotate_olddir="olddir "${LOGROTATE_OLDDIR}
  fi
}

syslogger_args=()

function resolveSysloggerArgs() {
  if [ -n "${SYSLOGGER_TAG}" ]; then
    syslogger_args=(-t "${SYSLOGGER_TAG}")
  fi
}

logrotate_mode="copytruncate"
function resolveLogrotateMode() {
  if [ -n "${LOGROTATE_MODE}" ]; then
    logrotate_mode="${LOGROTATE_MODE}"
  fi
}

logrotate_logfile_compression="nocompress"
logrotate_logfile_compression_delay=""

function resolveLogfileCompression() {
  if [ -n "${LOGROTATE_COMPRESSION}" ]; then
    logrotate_logfile_compression=${LOGROTATE_COMPRESSION}
    if [ ! "${logrotate_logfile_compression}" = "nocompress" ] && [ "${LOGROTATE_DELAYCOMPRESS}" != "false" ]; then
      logrotate_logfile_compression_delay="delaycompress"
    fi
  fi
}

logrotate_interval=${LOGROTATE_INTERVAL:-"daily"}

logrotate_copies=${LOGROTATE_COPIES:-"5"}

logrotate_size=""

function resolveLogrotateSize() {
  if [ -n "${LOGROTATE_SIZE}" ]; then
    logrotate_size="size "${LOGROTATE_SIZE}
  fi
}

logrotate_minsize=""

function resolveMinSize() {
  if [ -n "${LOGROTATE_MINSIZE}" ]; then
    logrotate_minsize="minsize ${LOGROTATE_MINSIZE}"
  fi
}

logrotate_maxage=""

function resolveMaxAge() {
  if [ -n "${LOGROTATE_MAXAGE}" ]; then
    logrotate_maxage="maxage ${LOGROTATE_MAXAGE}"
  fi
}

logrotate_autoupdate=true

function resolveLogrotateAutoupdate() {
  if [ -n "${LOGROTATE_AUTOUPDATE}" ]; then
    logrotate_autoupdate="${LOGROTATE_AUTOUPDATE,,}"
  fi
}

logrotate_prerotate=${LOGROTATE_PREROTATE_COMMAND:-""}

logrotate_postrotate=${LOGROTATE_POSTROTATE_COMMAND:-""}

logrotate_dateformat=${LOGROTATE_DATEFORMAT:-""}

resolveSysloggerArgs
resolveOldDir
resolveLogrotateMode
resolveLogfileCompression
resolveLogrotateSize
resolveLogrotateAutoupdate
resolveMinSize
resolveMaxAge
