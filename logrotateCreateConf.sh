#!/bin/bash
#
# Creation of Logfile

# Resolved paths already written to the configuration. logrotate rejects the whole
# run when a file appears twice, which happens with nested or repeated directories.
declare -A configured_files=()

# Suffixes logrotate appends to rotated copies: a counter (.1) or a date
# extension (-20260916, .2026-09-16), optionally followed by a compression extension.
readonly rotated_suffix_regex='^[-._][0-9][-._0-9]*(\.(gz|bz2|xz|zst|lz4|Z))?$'

# A file is a rotated copy when stripping such a suffix leaves the path of an existing file.
function isRotatedCopy() {
  local file="$1"
  local i
  for (( i=${#file}-1; i>0; i-- )); do
    case "${file:i:1}" in
      -|.|_)
        if [[ ${file:i} =~ ${rotated_suffix_regex} ]] && [ -f "${file:0:i}" ]; then
          return 0
        fi
      ;;
      /)
        return 1
      ;;
    esac
  done
  return 1
}

function handleSingleFile() {
  local singleFile="$1"
  local file_owner_user file_owner_group new_logrotate_entry resolved_file
  resolved_file=$(realpath "${singleFile}") || return 0
  if [ -n "${configured_files[${resolved_file}]}" ]; then
    return 0
  fi
  configured_files[${resolved_file}]=1
  if isRotatedCopy "${singleFile}"; then
    return 0
  fi
  # Skip files that disappear between discovery and stat instead of aborting under set -e.
  file_owner_user=$(stat -c %U "${singleFile}") || return 0
  file_owner_group=$(stat -c %G "${singleFile}") || return 0
  new_logrotate_entry=$(createLogrotateConfigurationEntry "${singleFile}" "${file_owner_user}" "${file_owner_group}" "${logrotate_copies}" "${logrotate_logfile_compression}" "${logrotate_logfile_compression_delay}" "${logrotate_mode}" "${logrotate_interval}" "${logrotate_size}" "${logrotate_dateformat}" "${logrotate_minsize}" "${logrotate_maxage}" "${logrotate_prerotate}" "${logrotate_postrotate}")
  echo "Inserting new ${singleFile} to ${logrotate_conf_file}"
  insertConfigurationEntry "$new_logrotate_entry" "${logrotate_conf_file}"
}

# ----- Logfile Crawling ------

log_dirs=${LOGS_DIRECTORIES}

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

# Group the name patterns so -type f and -print0 apply to all of them.
find_filter=()
if [ ${#find_name_args[@]} -gt 0 ]; then
  find_filter=(\( "${find_name_args[@]}" \))
fi

# Never crawl an absolute olddir: it only holds rotated copies.
find_prune=()
if [[ ${LOGROTATE_OLDDIR} == /* ]]; then
  find_prune=(-path "${LOGROTATE_OLDDIR%/}" -prune -o)
fi

# Read NUL-separated results so file names containing spaces stay intact.
for d in ${log_dirs}
do
  while IFS= read -r -d '' f
  do
    echo "Found new file $f, Processing..."
    handleSingleFile "$f"
  done < <(find "${d}" "${find_prune[@]}" -type f "${find_filter[@]}" -print0)
done

# ----- Take all Log in Subfolders ------

all_log_dirs=""

if [ -n "${ALL_LOGS_DIRECTORIES}" ]; then
  all_log_dirs=${ALL_LOGS_DIRECTORIES}
fi

for d in ${all_log_dirs}
do
  while IFS= read -r -d '' f
  do
    echo "Found new file $f, Processing..."
    handleSingleFile "$f"
  done < <(find "${d}" "${find_prune[@]}" -type f -print0)
done

cat "${logrotate_conf_file}"
