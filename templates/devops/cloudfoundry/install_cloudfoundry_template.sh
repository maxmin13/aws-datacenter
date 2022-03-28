#!/usr/bin/env bash

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# The script clones cf-deployment.git repository and deploys Cloud
# foundry using BOSH client. 
# A Bionic stem-cell is used instead of
# the Xenial stem-cell used in the deployment manifest file. 
####################################################################

BIN_DIR=$(dirname "${BASH_SOURCE[0]}")
source "${BIN_DIR}"/bbl_functions.sh
source "${BIN_DIR}"/bosh_functions.sh
source "${BIN_DIR}"/utils.sh

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
CF_DOWNLOAD_URL='SEDcf_download_urlSED'
CF_INSTALL_DIR='SEDcf_install_dirSED'
CF_LBAL_DOMAIN='SEDcf_lbal_domainSED'
CF_DEPLOYMENT_NM='cf'
BBL_INSTALL_DIR='SEDbbl_install_dirSED'
UBUNTU_BIONIC_STEMCELL_URL='SEDubuntu_bionic_stemcell_urlSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

echo 'Installing Cloud Foundy ...'

mkdir -p "${CF_INSTALL_DIR}" 
cd "${CF_INSTALL_DIR}" || exit 1
 
if [[ ! -d 'cf-deployment' ]]
then
  yum install -y git
  git clone "${CF_DOWNLOAD_URL}"
  yum remove -y git
fi

cp "${script_dir}"/cf_use_bionic_stemcell.yml "${CF_INSTALL_DIR}"
cp "${script_dir}"/cf_vars.yml "${CF_INSTALL_DIR}"

echo 'BOSH director has been installed with bbl, exporting bbl variables ...'
   
bbl_export_environment "${BBL_INSTALL_DIR}" 
   
echo 'BBL environment exported.'
   
bosh_login_director

echo 'Logged into BOSH director.'

echo 'Uplodading Ubuntu bionic stemcell ...'

bosh_upload_stemcell "${UBUNTU_BIONIC_STEMCELL_URL}"
  
echo 'Ubuntu bionic stemcell uploaded.'
echo 'Deploying Cloud Foundry ...'

remove_last_character_if_present "${CF_LBAL_DOMAIN}" '.'
lbal_domain_nm="${__RESULT}"

echo "Cloud Foundry load balancer name: ${lbal_domain_nm}"

bosh_deploy_cloud_foundry "${CF_DEPLOYMENT_NM}" "${lbal_domain_nm}" "${CF_INSTALL_DIR}"   
exit_code=$?

echo 'Cloud Foundry deployed.'

bosh_logout_director

echo 'Logged out from BOSH director.'

echo
   
exit 0

