#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

bosh_dir='bosh'

echo '***************'
echo 'Bosh components'
echo '***************'
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

get_instance_id "${ADMIN_INST_NM}"
admin_instance_id="${__RESULT}"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${admin_instance_id} (${instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
admin_sgp_id="${__RESULT}"

if [[ -z "${admin_sgp_id}" ]]
then
   echo '* WARN: Admin security group not found.'
else
   echo "* Admin security group ID: ${admin_sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
admin_eip="${__RESULT}"

if [[ -z "${admin_eip}" ]]
then
   echo '* WARN: Admin public IP address not found.'
else
   echo "* Admin public IP address: ${admin_eip}."
fi

echo

# Clear old files
rm -rf "${TMP_DIR:?}"/"${bosh_dir}"
mkdir "${TMP_DIR}"/"${bosh_dir}"









## 
## Security group.
## 

get_security_group_id "${BOSH_SEC_GRP_NM}"
bosh_sgp_id="${__RESULT}"

if [[ -n "${bosh_sgp_id}" ]]
then
   # Create Bosh security group.
   delete_security_group "${bosh_sgp_id}" 
   
   echo 'Bosh security group deleted.'
fi

## 
## SSH Key pair. 
## 

check_keypair_exists "${BOSH_KEY_PAIR_NM}"
keypair_exists="${__RESULT}"
key_pair_file="$(get_local_keypair_file_path "${BOSH_KEY_PAIR_NM}" "${BOSH_ACCESS_DIR}")"

if [[ 'true' == "${keypair_exists}" ]]
then  
   delete_keypair "${BOSH_KEY_PAIR_NM}" "${key_pair_file}"
   
   echo 'SSH keypair deleted.'
fi

jumpbox_key_pair_file="$(get_local_keypair_file_path "${JUMPBOX_KEY_PAIR_NM}" "${JUMPBOX_ACCESS_DIR}")"

if [[ 'true' == "${jumpbox_key_pair_file}" ]]
then  
   delete_keypair "${JUMPBOX_KEY_PAIR_NM}" "${jumpbox_key_pair_file}"
   
   echo 'SSH jumpbox keypair deleted.'
fi

## 
## SSH Access 
## 

set +e
revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Removed SSH access to the Admin box.'

echo

## Clearing.
rm -rf "${TMP_DIR:?}"/"${bosh_dir}"

# Delete Bosh work directory.
if [[ -d "${BOSH_WORKDIR_DIR}" ]]
then
   rm -rf "${BOSH_WORKDIR_DIR:?}"
fi

# Delete jumpbox work directory.
if [[ -d "${JUMPBOX_WORKDIR_DIR}" ]]
then
   rm -rf "${JUMPBOX_WORKDIR_DIR:?}"
fi

