#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH directory VM.
####################################################################

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

cd "${script_dir}" || exit

echo 'Removing Bosh director ...'

bosh delete-env bosh-deployment/bosh.yml \
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

echo 'Bosh director removed.'    
    
exit 0

