#!/bin/bash
#
# Creation of Logfile

function handleSingleFile() {
  local singleFile="$1"
  local file_owner_user=$(stat -c %U ${singleFile})
  local file_owner_group=$(stat -c %G ${singleFile})
  local new_logrotate_entry=$(createLogrotateConfigurationEntry "${singleFile}" "${file_owner_user}" "${file_owner_group}" "${logrotate_copies}" "${logrotate_logfile_compression}" "${logrotate_logfile_compression_delay}" "${logrotate_mode}" "${logrotate_interval}" "${logrotate_size}" "${logrotate_dateformat}" "${logrotate_minsize}" "${logrotate_maxage}" "${logrotate_prerotate}" "${logrotate_postrotate}")
  echo "Inserting new ${singleFile} to /usr/bin/logrotate.d/logrotate.conf"
  insertConfigurationEntry "$new_logrotate_entry" "/usr/bin/logrotate.d/logrotate.conf"
}

# ----- Logfile Crawling ------

log_dirs=""

if [ -n "${LOGS_DIRECTORIES}" ]; then
  log_dirs=${LOGS_DIRECTORIES}
else
  log_dirs=${log_dir}
fi

logs_ending="log"

if [ -n "${LOG_FILE_ENDINGS}" ]; then
  logs_ending=${LOG_FILE_ENDINGS}
fi

# Keep find arguments in an array so patterns like *.log reach find as-is
# instead of being expanded by the shell against the current directory.
find_name_args=()
read -ra endings <<< "${logs_ending}"
for ending in "${endings[@]}"
do
  if [ ${#find_name_args[@]} -gt 0 ]; then
    find_name_args+=(-o)
  fi
  find_name_args+=(-iname "*.${ending}")
done

# Check if regex search is enabled
if [ -n "${LOGS_FILE_REGEX}" ]; then
  if [ ${#find_name_args[@]} -gt 0 ]; then
    find_name_args+=(-o)
  fi
  find_name_args+=(-regex "${LOGS_FILE_REGEX}")
fi

for d in ${log_dirs}
do
  log_files=$(find ${d} -type f "${find_name_args[@]}") || continue
  for f in ${log_files};
  do
    if [ -f "${f}" ]; then
      echo "Found new file $f, Processing..."
      handleSingleFile "$f"
    fi
  done
done

# ----- Take all Log in Subfolders ------

all_log_dirs=""

if [ -n "${ALL_LOGS_DIRECTORIES}" ]; then
  all_log_dirs=${ALL_LOGS_DIRECTORIES}
fi

for d in ${all_log_dirs}
do
  log_files=$(find ${d} -type f);
  for f in ${log_files};
  do
    if [ -f "${f}" ]; then
      echo "Found new file $f, Processing..."
      handleSingleFile "$f"
    fi
  done
done

cat /usr/bin/logrotate.d/logrotate.conf
