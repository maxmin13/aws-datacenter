#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Remove Devops components:
# BOSH client, BOSH bootloader client, BOSH 
# director, Cloud Foundry.
####################################################################

devops_log_file='/var/log/devops_delete.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Removing Devops components ...'

#
# Cloud Foundry.
#

cd "${script_dir}" || exit
chmod +x delete_cloudfoundry.sh 
./delete_cloudfoundry.sh >> "${devops_log_file}" 2>&1

#
# Bosh director.
#

cd "${script_dir}" || exit
chmod +x delete_boshdirector_with_bbl.sh 
./delete_boshdirector_with_bbl.sh >> "${devops_log_file}" 2>&1

#
# Bosh client.
#

cd "${script_dir}" || exit
chmod +x delete_bosh_cli.sh 
./delete_bosh_cli.sh >> "${devops_log_file}" 2>&1

#
# Bosh bootloader client.
#

cd "${script_dir}" || exit
chmod +x delete_bbl_cli.sh 
./delete_bbl_cli.sh >> "${devops_log_file}" 2>&1

echo 'Devops components deleted.'

exit 0
