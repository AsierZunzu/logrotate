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

# Checks the environment once at startup. Invalid values abort with every error
# listed; settings that are merely suspicious only print a warning.
function validateConfiguration() {
  local errors=0
  local d

  if [ -n "${LOGROTATE_INTERVAL}" ] && [[ ! ${LOGROTATE_INTERVAL} =~ ^(hourly|daily|weekly|monthly|yearly)$ ]]; then
    echo "Error: LOGROTATE_INTERVAL must be hourly, daily, weekly, monthly or yearly, got '${LOGROTATE_INTERVAL}'" >&2
    errors=$((errors + 1))
  fi
  if [ -n "${LOGROTATE_COMPRESSION}" ] && [[ ! ${LOGROTATE_COMPRESSION} =~ ^(compress|nocompress)$ ]]; then
    echo "Error: LOGROTATE_COMPRESSION must be compress or nocompress, got '${LOGROTATE_COMPRESSION}'" >&2
    errors=$((errors + 1))
  fi
  if [ -n "${LOGROTATE_COPIES}" ] && [[ ! ${LOGROTATE_COPIES} =~ ^[0-9]+$ ]]; then
    echo "Error: LOGROTATE_COPIES must be a number, got '${LOGROTATE_COPIES}'" >&2
    errors=$((errors + 1))
  fi
  if [ -n "${LOGROTATE_MAXAGE}" ] && [[ ! ${LOGROTATE_MAXAGE} =~ ^[0-9]+$ ]]; then
    echo "Error: LOGROTATE_MAXAGE must be a number of days, got '${LOGROTATE_MAXAGE}'" >&2
    errors=$((errors + 1))
  fi
  if [ -n "${LOGROTATE_SIZE}" ] && [[ ! ${LOGROTATE_SIZE} =~ ^[0-9]+[kMG]?$ ]]; then
    echo "Error: LOGROTATE_SIZE must be a size like 100, 100k, 100M or 100G, got '${LOGROTATE_SIZE}'" >&2
    errors=$((errors + 1))
  fi
  if [ -n "${LOGROTATE_MINSIZE}" ] && [[ ! ${LOGROTATE_MINSIZE} =~ ^[0-9]+[kMG]?$ ]]; then
    echo "Error: LOGROTATE_MINSIZE must be a size like 100, 100k, 100M or 100G, got '${LOGROTATE_MINSIZE}'" >&2
    errors=$((errors + 1))
  fi
  if [ -n "${DELAYED_START}" ] && [[ ! ${DELAYED_START} =~ ^[0-9]+[smhd]?$ ]]; then
    echo "Error: DELAYED_START must be a number of seconds, optionally with an s, m, h or d suffix, got '${DELAYED_START}'" >&2
    errors=$((errors + 1))
  fi

  if [ -n "${LOGROTATE_AUTOUPDATE}" ] && [[ ! ${LOGROTATE_AUTOUPDATE,,} =~ ^(true|false)$ ]]; then
    echo "Warning: LOGROTATE_AUTOUPDATE is '${LOGROTATE_AUTOUPDATE}', which disables auto update; use true or false" >&2
  fi
  if [ -z "${LOGS_DIRECTORIES}${ALL_LOGS_DIRECTORIES}" ]; then
    echo "Warning: neither LOGS_DIRECTORIES nor ALL_LOGS_DIRECTORIES is set, no logs will be rotated" >&2
  fi
  # Unquoted on purpose: directories are whitespace separated.
  for d in ${LOGS_DIRECTORIES} ${ALL_LOGS_DIRECTORIES}; do
    if [ ! -d "${d}" ]; then
      echo "Warning: log directory ${d} does not exist" >&2
    fi
  done

  if [ "${errors}" -gt 0 ]; then
    return 1
  fi
}

resolveSysloggerArgs
resolveOldDir
resolveLogrotateMode
resolveLogfileCompression
resolveLogrotateSize
resolveLogrotateAutoupdate
resolveMinSize
resolveMaxAge
