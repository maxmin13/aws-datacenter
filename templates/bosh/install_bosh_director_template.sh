#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH directory VM.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
BOSH_DIRECTOR_INSTALL_DIR='SEDbosh_director_install_dirSED'
BOSH_GATEWAY_IP='SEDbosh_gateway_ipSED'
BOSH_DIRECTOR_NM='SEDbosh_director_nmSED'
BOSH_CIDR='SEDbosh_cidrSED'
BOSH_REGION='SEDbosh_regionSED'
BOSH_AZ='SEDbosh_azSED'
BOSH_SUBNET_ID='SEDbosh_subnet_idSED'
BOSH_SEC_GROUP_NM='SEDbosh_sec_group_nmSED'
BOSH_INTERNAL_IP='SEDbosh_internal_ipSED'
BOSH_KEY_PAIR_NM='SEDbosh_key_pair_nmSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

cd "${script_dir}" || exit

yum install -y git

mkdir -p "${BOSH_DIRECTOR_INSTALL_DIR}"
cp set_director_passwd.yml vars.yml "${BOSH_KEY_PAIR_NM}" "${BOSH_DIRECTOR_INSTALL_DIR}"

cd "${BOSH_DIRECTOR_INSTALL_DIR}" || exit

chmod 400 set_director_passwd.yml vars.yml "${BOSH_KEY_PAIR_NM}"

git clone https://github.com/cloudfoundry/bosh-deployment
yum remove -y git

echo 'Creating BOSH director ...'

bosh create-env bosh-deployment/bosh.yml \
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
    
echo 'BOSH director created.'    
    
chmod 400 state.json creds.yml   

# Loads BOSH context.
bosh alias-env "${BOSH_DIRECTOR_NM}" -e "${BOSH_INTERNAL_IP}" --ca-cert <(bosh int ./creds.yml --path /director_ssl/ca)

export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET="$(bosh int ./creds.yml --path /admin_password)"
export BOSH_ENVIRONMENT="${BOSH_DIRECTOR_NM}" 

echo 'BOSH context loaded.'

# Show current env.
bosh env  

# Set basic cloud config.
bosh update-cloud-config bosh-deployment/aws/cloud-config.yml \
    -v az="${BOSH_AZ}" \
    -v internal_cidr="${BOSH_CIDR}" \
    -v internal_gw="${BOSH_GATEWAY_IP}" \
    -v subnet_id="${BOSH_SUBNET_ID}" \
    --non-interactive
    
echo 'BOSH basic cloud configuration set.'    
    
# Show deployments (should be empty).
bosh deployments

# Show vms (should be empty)
bosh vms
    
exit 0

