#!/usr/bin/env bash

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# BOSH (bosh outer shell) is a release-engineering tool chain that 
# provides an easy mechanism to version, package, and deploy 
# cloud based software: BOSH outer shell runs Clound Foundry so that
# Cloud Foundry can run your apps.
# BOSH supports deploying to multiple IaaS providers.
# BOSH focuses on defining your infrastructure as a piece of code.
#
####################################################################

BIN_DIR=$(dirname "${BASH_SOURCE[0]}")
source "${BIN_DIR}"/bbl_functions.sh
source "${BIN_DIR}"/utils.sh

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
REGION='SEDregionSED'
BBL_INSTALL_DIR='SEDbbl_install_dirSED'
ACCESS_KEY_ID='SEDaccess_key_idSED'
SECRET_ACCESS_KEY='SEDsecret_access_keySED'
CF_LBAL_DOMAIN='SEDcf_lbal_domainSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

cd "${script_dir}" || exit

echo 'Generating SSL key and self-signed certificate for the Cloud Foundry load balancer ...'

chmod +x gen_selfsigned_certificate.sh
./gen_selfsigned_certificate.sh

mkdir -p "${BBL_INSTALL_DIR}"
mv cert.pem "${BBL_INSTALL_DIR}"/lbal_cert.pem
mv key.pem "${BBL_INSTALL_DIR}"/lbal_key.pem

lbal_cert_file="${BBL_INSTALL_DIR}"/lbal_cert.pem
lbal_key="${BBL_INSTALL_DIR}"/lbal_key.pem

chmod 400 "${lbal_cert_file}"
chmod 400 "${lbal_key}"

echo 'SSL key and self-signed certificate for the Cloud Foundry load balancer generated.'

cp create-director-override.sh enable_debug.yml disable_debug.yml director_vars.yml "${BBL_INSTALL_DIR}"

chmod 700 "${BBL_INSTALL_DIR}"/create-director-override.sh "${BBL_INSTALL_DIR}"/enable_debug.yml \
    "${BBL_INSTALL_DIR}"/disable_debug.yml "${BBL_INSTALL_DIR}"/director_vars.yml

remove_last_character_if_present "${CF_LBAL_DOMAIN}" '.'
lbal_domain_nm="${__RESULT}"

echo "Cloud Foundry load balancer name: ${lbal_domain_nm}"
echo 'Running BOSH bootloader plan ...'

bbl_plan_director "${BBL_INSTALL_DIR}" "${ACCESS_KEY_ID}" "${SECRET_ACCESS_KEY}" "${REGION}" \
    "${lbal_cert_file}" "${lbal_key}" "${lbal_domain_nm}" 

echo 'BOSH bootloader plan executed.'
echo 'Bootstrapping BOSH director ...'

bbl_bootstrap_director "${BBL_INSTALL_DIR}" "${ACCESS_KEY_ID}" "${SECRET_ACCESS_KEY}" "${REGION}" \
    "${lbal_cert_file}" "${lbal_key}" "${CF_LBAL_DOMAIN}"   
    
echo 'BOSH director successfully bootstrapped.'

echo
   
exit 0

