#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

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

sgp_id="$(get_security_group_id "${BOSH_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Bosh security group not found.'
else
   echo "* Bosh security group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${BOSH_INST_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Bosh public IP address not found.'
else
   echo "* Bosh public IP address: ${eip}."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${cf_dir}"
mkdir "${TMP_DIR}"/"${cf_dir}"

key_pair_file="$(get_local_keypair_file_path "${BOSH_KEY_PAIR_NM}" "${BOSH_ACCESS_DIR}")"
check_keypair_exists "${BOSH_KEY_PAIR_NM}"
keypair_exists="${__RESULT}"

##
## Bosh director.
##

cd "${BOSH_WORK_DIR}"

## TODO remove hardcoded credentials

bosh delete-env bosh-deployment/bosh.yml \
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

# Delete Bosh work directory.
if [[ -d "${BOSH_WORK_DIR}" ]]
then
   rm -rf "${BOSH_WORK_DIR:?}/*"
fi

## 
## Security group. 
## 
  
if [[ -n "${sgp_id}" ]]
then  
   set +e
   revoke_access_from_security_group  "${sgp_id}" '0 - 65535' 'tcp' "${sgp_id}" > /dev/null 2>&1
   revoke_access_from_security_group  "${sgp_id}" '0 - 65535' 'udp' "${sgp_id}" > /dev/null 2>&1
   set -e
   
   echo 'revoked access from security group to all TCP/UDP ports.'
   
   delete_security_group "${sgp_id}"
   
   echo 'Security group deleted.'
fi

## 
## Public IP. 
## 

if [[ -n "${eip}" ]]
then
   allocation_id="$(get_allocation_id "${eip}")"  
   
   if [[ -n "${allocation_id}" ]] 
   then
      release_public_ip_address "${allocation_id}"
   fi
   
   echo "Public IP address released from the account." 
fi

## 
## SSH Key pair. 
## 

if [[ 'true' == "${keypair_exists}" ]]
then  
   delete_keypair "${BOSH_KEY_PAIR_NM}" "${key_pair_file}"
   
   echo 'SSH keypair deleted.'
fi

echo

## Clearing.
rm -rf "${TMP_DIR:?}"/"${cf_dir}"

