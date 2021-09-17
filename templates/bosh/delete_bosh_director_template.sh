#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH directory VM.
####################################################################

BOSH_GATEWAY_IP='SEDbosh_gateway_ipSED'
BOSH_DIRECTOR_INSTALL_DIR='SEDbosh_director_install_dirSED'
BOSH_DIRECTOR_NM='SEDbosh_director_nmSED'
BOSH_CIDR='SEDbosh_cidrSED'
BOSH_REGION='SEDbosh_regionSED'
BOSH_AZ='SEDbosh_azSED'
BOSH_SUBNET_ID='SEDbosh_subnet_idSED'
BOSH_SEC_GROUP_NM='SEDbosh_sec_group_nmSED'
BOSH_INTERNAL_IP='SEDbosh_internal_ipSED'
BOSH_KEY_PAIR_NM='SEDbosh_key_pair_nmSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${BOSH_DIRECTOR_INSTALL_DIR}" || exit

if [[ -f /usr/bin/bosh ]]
then
   echo 'Removing Bosh director ...'

   bosh delete-env bosh-deployment/bosh.yml \
    --state=state.json \
    --vars-store=creds.yml \
    -o bosh-deployment/aws/cpi.yml \
    -o bosh-deployment/aws/iam-instance-profile.yml \
    -o set_director_passwd.yml \
    -v director_name="${BOSH_DIRECTOR_NM}" \
    -v subnet_id="${BOSH_SUBNET_ID}" \
    -v internal_cidr="${BOSH_CIDR}" \
    -v internal_gw="${BOSH_GATEWAY_IP}" \
    -v internal_ip="${BOSH_INTERNAL_IP}" \
    -v region="${BOSH_REGION}" \
    -v az="${BOSH_AZ}" \
    -v default_key_name="${BOSH_KEY_PAIR_NM}" \
    -v default_security_groups=["${BOSH_SEC_GROUP_NM}"] \
    --var-file private_key="${BOSH_KEY_PAIR_NM}" \
    -v access_key_id="AKIA6ASSBNWH2DAOMT2S" \
    -v secret_access_key="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" \
    --vars-file vars.yml 
    
    ####################
    ### TODO DO NOT COMMIT the keys!!!!!!!!!!!!!!!!!!!!!!!!!
    
   echo 'Bosh director removed.'  
else
   echo 'WARN: bosh client not found.'
fi 
    
rm -rf bosh-deployment    

echo 'Bosh deployment dir removed.' 
    
exit 0

