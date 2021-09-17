#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH components.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
bosh_log_file='/var/log/bosh_install.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

cd "${script_dir}" || exit

echo 'Installing Bosh components ...'

chmod +x install_bosh_cli.sh 
./install_bosh_cli.sh ####>> "${bosh_log_file}" 2>&1

cd "${script_dir}" || exit

chmod +x install_bosh_director.sh 
./install_bosh_director.sh ####>> "${bosh_log_file}" 2>&1

echo 'Bosh components installed.'

exit 0
