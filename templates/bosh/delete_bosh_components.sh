#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Remove BOSH components.
####################################################################

bosh_log_file='/var/log/bosh_delete.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${script_dir}" || exit

echo 'Removing Bosh components ...'

chmod +x delete_bosh_director.sh 
./delete_bosh_director.sh >> "${bosh_log_file}" 2>&1

chmod +x delete_bosh_cli.sh 
./delete_bosh_cli.sh >> "${bosh_log_file}" 2>&1

cd "${script_dir}" || exit

echo 'Bosh components deleted.'

exit 0
