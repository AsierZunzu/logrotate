#!/bin/bash
#
# Helper functions for manipulating logrotate configurationsfile

function createLogrotateConfigurationEntry() {
  local file="$1"
  local file_user="$2"
  local file_owner="$3"
  local conf_copies="$4"
  local conf_logfile_compression="$5"
  local conf_logfile_compression_delay="$6"
  local conf_logrotate_mode="$7"
  local conf_logrotate_interval="$8"
  local conf_logrotate_size="$9"
  local conf_dateformat="${10}"
  local conf_minsize="${11}"
  local conf_maxage="${12}"
  local conf_prerotate="${13}"
  local conf_postrotate="${14}"
  local nl=$'\n'
  local new_log
  # Escape backslashes and double quotes so the name survives logrotate's quoting.
  file=${file//\\/\\\\}
  file=${file//\"/\\\"}
  new_log="\"${file}\" {"
  if [ "$file_user" != "UNKNOWN" ] && [ "$file_owner" != "UNKNOWN" ]; then
    new_log+="${nl}  su ${file_user} ${file_owner}"
  else
    # logrotate only accepts names in su, and without it skips logs whose
    # directory is group or world writable.
    new_log+="${nl}  su root root"
  fi
  new_log+="${nl}  rotate ${conf_copies}"
  new_log+="${nl}  missingok"
  local directive
  for directive in "${conf_logfile_compression}" "${conf_logfile_compression_delay}" "${conf_logrotate_mode}" "${conf_logrotate_interval}" "${conf_logrotate_size}" "${conf_minsize}" "${conf_maxage}"; do
    if [ -n "${directive}" ]; then
      new_log+="${nl}  ${directive}"
    fi
  done
  if [ -n "${conf_dateformat}" ]; then
    new_log+="${nl}  dateext${nl}  dateformat ${conf_dateformat}"
  fi
  if [ -n "${conf_prerotate}" ]; then
    new_log+="${nl}  prerotate${nl}    ${conf_prerotate}${nl}  endscript"
  fi
  if [ -n "${conf_postrotate}" ]; then
    new_log+="${nl}  postrotate${nl}    ${conf_postrotate}${nl}  endscript"
  fi
  new_log+="${nl}}"
  # printf instead of echo -e: backslashes in names and commands stay literal.
  printf '%s\n' "${new_log}"
}

function insertConfigurationEntry()
{
  local config=$1
  local config_file=$2

  cat >> "$config_file" <<_EOF_
${config}
_EOF_
}
