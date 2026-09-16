#!/bin/bash
#
# A helper script for updating the generated logrotate.conf.

set -e

[[ ${DEBUG} == true ]] && set -x

source /usr/bin/logrotate.d/logrotate.sh
source /usr/bin/logrotate.d/logrotateConf.sh

resetConfigurationFile

# Runs before every rotation: only report the total instead of each file again.
logrotate_list_files=false

#Create Logrotate Conf
source /usr/bin/logrotate.d/logrotateCreateConf.sh
