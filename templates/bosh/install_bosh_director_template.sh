#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH directory VM.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
BOSH_GATEWAY_IP='SEDbosh_gateway_ipSED'
BOSH_DIRECTOR_NM='SEDbosh_director_nmSED'
BOSH_DIRECTOR_CIDR='SEDbosh_director_cidrSED'
BOSH_DIRECTOR_REGION='SEDbosh_director_regionSED'
BOSH_DIRECTOR_AZ='SEDbosh_director_azSED'
BOSH_DIRECTOR_SUBNET_ID='SEDbosh_director_subnet_idSED'
BOSH_DIRECTOR_SEC_GROUP_NM='SEDbosh_director_sec_group_nmSED'
BOSH_DIRECTOR_INTERNAL_IP='SEDbosh_director_internal_ipSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change ownership in the script directory to delete it from dev machine.
trap "chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}" ERR EXIT

cd "${script_dir}" || exit

git clone https://github.com/cloudfoundry/bosh-deployment

bosh create-env \
    --state=state.json \
    bosh-deployment/bosh.yml \
    --vars-store=creds.yml \
    -o bosh-deployment/aws/cpi.yml \
    -o set_director_passwd.yml \
    -v director_name="${BOSH_DIRECTOR_NM}" \
    -v internal_cidr="${BOSH_DIRECTOR_CIDR}" \
    -v internal_gw="${BOSH_GATEWAY_IP}" \
    -v internal_ip="${BOSH_DIRECTOR_INTERNAL_IP}" \
    -v access_key_id=$aws_access_key_id \\
    -v secret_access_key=$aws_secret \\
    -v region="${BOSH_DIRECTOR_REGION}" \
    -v az="${BOSH_DIRECTOR_AZ}" \
    -v default_key_name=$vpcName \\
    -v default_security_groups=["${BOSH_DIRECTOR_SEC_GROUP_NM}"] \
    --var-file private_key=${keypairName}.pem \\
    -v subnet_id="${BOSH_DIRECTOR_SUBNET_ID}" \
    --vars-file vars.yml 

exit 0

