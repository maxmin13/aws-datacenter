#!/usr/bin/env bash

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# BOSH (bosh outer shell) is a release-engineering tool chain that 
# provides an easy mechanism to version, package, and deploy 
# cloud based software.
####################################################################

BIN_DIR=$(dirname "${BASH_SOURCE[0]}")
source "${BIN_DIR}"/bbl_functions.sh

ACCESS_KEY_ID='SEDaccess_key_idSED'
SECRET_ACCESS_KEY='SEDsecret_access_keySED'
REGION='SEDregionSED'
BBL_INSTALL_DIR='SEDbbl_install_dirSED'
CF_LBAL_DOMAIN='SEDcf_lbal_domainSED'

# Check if BOSH bootloader install directory is present.

if [[ ! -d "${BBL_INSTALL_DIR}" ]]
then
   echo 'WARN: BOSH bootloader install directory not found, skipping removing BOSH director.'
   exit 0
fi

echo 'Removing BOSH director ...'

lbal_file="${BBL_INSTALL_DIR}"/lbal_cert.pem
lbal_key="${BBL_INSTALL_DIR}"/lbal_key.pem

bbl_delete_director "${BBL_INSTALL_DIR}" "${ACCESS_KEY_ID}" "${SECRET_ACCESS_KEY}" "${REGION}" \
    "${lbal_file}" "${lbal_key}" "${CF_LBAL_DOMAIN}"
   
echo 'BOSH director successfully removed.'

if [[ 0 -eq "${exit_code}" ]]
then
   rm -rf "${BBL_INSTALL_DIR:?}"
   
   echo 'BOSH bootloader install directory deleted.'
fi

echo
   
exit 0

