#!/usr/bin/env bash

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace  

#####################################################################
# Deletes Cloud Foundry deployment using BOSH client.
#####################################################################

BIN_DIR=$(dirname "${BASH_SOURCE[0]}")
source "${BIN_DIR}"/bbl_functions.sh
source "${BIN_DIR}"/bosh_functions.sh

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
CF_INSTALL_DIR='SEDcf_install_dirSED'
CF_DEPLOYMENT_NM='cf'
BBL_INSTALL_DIR='SEDbbl_install_dirSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

# Check if BOSH bootloader install directory is present.

if [[ ! -d "${BBL_INSTALL_DIR}" ]]
then
   echo 'WARN: BOSH bootloader install directory not found, skipping removing Cloud Foundry.'
   exit 0
fi

echo 'BOSH director has been installed with bbl, exporting bbl variables ...'
   
bbl_export_environment "${BBL_INSTALL_DIR}" 
   
echo 'BBL environment exported.'
  
  #### TODO error if bosh director not installed, check. 
bosh_login_director

echo 'Logged into BOSH director.'
echo 'Deleting Cloud Foundy ...'

bosh_delete_cloud_foundry "${CF_DEPLOYMENT_NM}"

echo 'Cloud Foundry deleted.'   

rm -rf "${CF_INSTALL_DIR:?}" 

echo 'Cloud Foundry directory deleted.'

bosh_logout_director

echo 'Logged out from BOSH director.'

echo
   
exit 0

