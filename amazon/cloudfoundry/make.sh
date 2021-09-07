#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# 
#
###############################################

cf_dir='cloudfoundry'

echo '*************'
echo 'Cloud Foundry'
echo '*************'
echo

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${subnet_id}."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${cf_dir}"
mkdir "${TMP_DIR}"/"${cf_dir}"

## 
## Security group.
## 

sgp_id="$(get_security_group_id "${BOSH_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   sgp_id="$(create_security_group "${dtc_id}" "${BOSH_SEC_GRP_NM}" 'BOSH deployed VMs.')"  
   
   echo 'Created Bosh security group.'.
else
   echo 'WARN: Bosh security group is already created.'
fi

set +e
allow_access_from_cidr "${sgp_id}" "${BOSH_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
echo 'Granted SSH access to Bosh CLI.'

allow_access_from_cidr "${sgp_id}" "${BOSH_AGENT_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
echo 'Granted access to Bosh agent.'

allow_access_from_cidr "${sgp_id}" "${BOSH_DIRECTOR_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
echo 'Granted access to Bosh director.'

allow_access_from_security_group "${sgp_id}" '0 - 65535' 'tcp' "${sgp_id}" > /dev/null 2>&1
   
echo 'Granted access from security group to all TPC ports.'

allow_access_from_security_group "${sgp_id}" '0 - 65535' 'udp' "${sgp_id}" > /dev/null 2>&1

echo 'Granted access from security group to all UDP ports.'
set -e

## 
## SSH Key pair. 
## 


check_keypair_exists "${BOSH_KEY_PAIR_NM}"
keypair_exists="${__RESULT}"
key_pair_file="$(get_local_keypair_file_path "${BOSH_KEY_PAIR_NM}" "${BOSH_ACCESS_DIR}")"

if [[ 'true' == "${keypair_exists}" ]]
then
   echo 'WARN: found SSH keypair, deleting it...'
   
   delete_keypair "${BOSH_KEY_PAIR_NM}" "${key_pair_file}"
   
   echo 'SSH keypair deleted.'
fi

# Save the private key file in the access directory
mkdir -p "${BOSH_ACCESS_DIR}"
generate_keypair "${BOSH_KEY_PAIR_NM}" "${key_pair_file}"
      
echo 'SSH keypair generated.'

##
## Public IP.
##

# Check if an IP address is allocated to the account and not used by any EC2 instance.

get_unused_public_ip_address
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   allocate_public_ip_address
   eip="${__RESULT}"

   echo "Allocated ${eip} address to the account."
else
   echo "WARN: found ${eip} address allocated to the account."
fi

##
## Bosh director.
##

# Create directory to keep state. 
if [[ -d "${BOSH_WORK_DIR}" ]]
then
   rm -rf "${BOSH_WORK_DIR:?}"
fi

mkdir -p "${BOSH_WORK_DIR}"
cd "${BOSH_WORK_DIR}"

git clone -q "${CF_BOSH_DEPLOYMENT_URL}" > /dev/null

# Deploy Bosh director.

temp_credentials="$(aws sts get-session-token --query "Credentials.[AccessKeyId, SecretAccessKey]" --output text)"
array=(${temp_credentials})
access_key="${array[0]}"
secret_key="${array[1]}"

## TODO use a Admin instance as jumpbox instead of a public ip from dev.
##
## TODO remove hardcoded credentials

# Check if the director is deployed.
bosh envs

bosh create-env bosh-deployment/bosh.yml \
    --state=state.json \
    --vars-store=creds.yml \
    -o bosh-deployment/aws/cpi.yml \
    -o bosh-deployment/external-ip-with-registry-not-recommended.yml \
    -v director_name="${BOSH_DIRECTOR_NM}" \
    -v internal_cidr=${DTC_SUBNET_MAIN_CIDR} \
    -v internal_gw="${DTC_SUBNET_MAIN_INTERNAL_GW}" \
    -v internal_ip="${BOSH_DIRECTOR_INTERNAL_IP}" \
    -v access_key_id="${ACCESS_KEY}" \
    -v secret_access_key="${SECRET_KEY}" \
    -v region="${DTC_DEPLOY_REGION}" \
    -v az="${DTC_DEPLOY_ZONE_1}" \
    -v default_key_name="${BOSH_KEY_PAIR_NM}" \
    -v default_security_groups=["${BOSH_SEC_GRP_NM}"] \
    --var-file private_key="${key_pair_file}" \
    -v subnet_id="${subnet_id}" \
    -v external_ip="${eip}"    
    
# Removing temp files
#####rm -rf "${TMP_DIR:?}"/"${cf_dir}"  

echo
echo "Cloud Foundry installed." 
echo
