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
## Instance profile.
##

check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE}" > /dev/null
has_role_associated="${__RESULT}"

if [[ 'true' == "${has_role_associated}" ]]
then
   ####
   #### Sessions may still be actives, they should be terminated by adding AWSRevokeOlderSessions permission
   #### to the role.
   ####
   remove_role_from_instance_profile "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE}"
  
   echo 'Bosh director role removed from the instance profile.'
else
   echo 'WARN: Bosh director role already removed from the instance profile.'
fi


## 
## Security group.
## 

get_security_group_id "${BOSH_INST_SEC_GRP_NM}"
bosh_sgp_id="${__RESULT}"

if [[ -n "${bosh_sgp_id}" ]]
then
   # Create Bosh security group.
   delete_security_group "${bosh_sgp_id}" 
   
   echo 'Bosh security group deleted.'
fi

## 
## Bosh SSH Key pair. 
## 

check_keypair_exists "${BOSH_INST_KEY_PAIR_NM}" "${BOSH_ACCESS_DIR}"
keypair_exists="${__RESULT}"
key_pair_file="${BOSH_ACCESS_DIR}"/"${BOSH_INST_KEY_PAIR_NM}" 

if [[ 'true' == "${keypair_exists}" ]]
then  
   delete_keypair "${BOSH_INST_KEY_PAIR_NM}" "${key_pair_file}"
   
   echo 'SSH keypair deleted.'
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



