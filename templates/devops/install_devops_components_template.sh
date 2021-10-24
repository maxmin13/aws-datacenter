#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install Devops components:
# BOSH client, Terraform client, BOSH bootloader client, BOSH 
# director, Cloud Foundry.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
devops_log_file='/var/log/devops_install.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export BOSH_LOG_PATH="${devops_log_file}"

trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

echo 'Installing devops components ...'

#
# Bosh client.
#

cd "${script_dir}" || exit
chmod +x install_bosh_cli.sh 
./install_bosh_cli.sh >> "${devops_log_file}" 2>&1

#
# Terraform client.
#

cd "${script_dir}" || exit
chmod +x install_terraform_cli.sh 
./install_terraform_cli.sh >> "${devops_log_file}" 2>&1

#
# Bosh bootloader client.
#

cd "${script_dir}" || exit
chmod +x install_bbl_cli.sh 
./install_bbl_cli.sh >> "${devops_log_file}" 2>&1

#
# Bosh director.
#

cd "${script_dir}" || exit
chmod +x install_boshdirector_with_bbl.sh
./install_boshdirector_with_bbl.sh >> "${devops_log_file}" 2>&1

#cd "${script_dir}" || exit
#chmod +x install_boshdirector.sh 
#./install_boshdirector.sh >> "${devops_log_file}" 2>&1

#
# Cloud Foundry.
#

cd "${script_dir}" || exit
chmod +x install_cloudfoundry.sh 
./install_cloudfoundry.sh >> "${devops_log_file}" 2>&1

echo 'Devops components installed.'

exit 0