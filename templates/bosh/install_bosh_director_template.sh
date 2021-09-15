#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH directory VM.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
DTC_GATEWAY_IP='SEDdtc_gateway_ipSED'
BOSH_DIRECTOR_NM='SEDbosh_director_nmSED'
BOSH_CIDR='SEDbosh_cidrSED'
BOSH_REGION='SEDbosh_regionSED'
BOSH_AZ='SEDbosh_azSED'
BOSH_SUBNET_ID='SEDbosh_subnet_idSED'
BOSH_SEC_GROUP_NM='SEDbosh_sec_group_nmSED'
BOSH_INTERNAL_IP='SEDbosh_internal_ipSED'
BOSH_PRIVATE_KEY='SEDprivate_keySED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

cd "${script_dir}" || exit

yum install -y git
git clone https://github.com/cloudfoundry/bosh-deployment

bosh create-env bosh-deployment/bosh.yml \
    --state=state.json \
    --vars-store=creds.yml \
    -o bosh-deployment/aws/cpi.yml \
    -o set_director_passwd.yml \
    -o set_director_instance_profile.yml \
    -v director_name="${BOSH_DIRECTOR_NM}" \
    -v subnet_id="${BOSH_SUBNET_ID}" \
    -v internal_cidr="${BOSH_CIDR}" \
    -v internal_gw="${DTC_GATEWAY_IP}" \
    -v internal_ip="${BOSH_INTERNAL_IP}" \
    -v region="${BOSH_REGION}" \
    -v az="${BOSH_AZ}" \
    -v default_key_name="${BOSH_PRIVATE_KEY}" \
    -v default_security_groups=["${BOSH_SEC_GROUP_NM}"] \
    --var-file private_key="${BOSH_PRIVATE_KEY}" \
    --vars-file vars.yml 
    
yum remove -y git    

exit 0

