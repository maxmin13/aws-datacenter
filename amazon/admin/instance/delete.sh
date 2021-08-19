#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

ADMIN_INST_PROFILE_NM="Route53InstanceProfile"

echo '*********'
echo 'Admin box'
echo '*********'
echo

instance_id="$(get_instance_id "${ADMIN_INST_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   instance_st="$(get_instance_state "${ADMIN_INST_NM}")"
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

sgp_id="$(get_security_group_id "${ADMIN_INST_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Admin security group not found.'
else
   echo "* Admin security group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Admin public IP address not found.'
else
   echo "* Admin public IP address: ${eip}."
fi

db_sgp_id="$(get_security_group_id "${DB_INST_SEC_GRP_NM}")"

if [[ -z "${db_sgp_id}" ]]
then
   echo '* WARN: database security group not found.'
else
   echo "* database security group ID: ${db_sgp_id}."
fi

get_instance_profile_id "${ADMIN_INST_PROFILE_NM}"
profile_id="${__RESULT}"

if [[ -z "${profile_id}" ]]
then
   echo '* WARN: Admin instance profile not found.'
else
   echo "* Admin instance profile ID: ${profile_id}."
fi

echo

## 
## Clearing local files.
## 
rm -rf "${TMP_DIR:?}"/admin

##
## Instance profile.
##

check_instance_profile_exists "${ADMIN_INST_PROFILE_NM}"
instance_profile_exists="${__RESULT}"

if [[ 'true' == "${instance_profile_exists}" ]]
then
   delete_instance_profile "${ADMIN_INST_PROFILE_NM}"

   echo 'Admin instance profile deleted.'
fi

##
## Admin box. 
## 

if [[ -n "${instance_id}" ]]
then
   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting Admin box ..."
      
      delete_instance "${instance_id}" 'and_wait'
      
      echo 'Admin box deleted.'
   fi
fi

## 
## Database grants. 
## 

db_sgp_id="$(get_security_group_id "${DB_INST_SEC_GRP_NM}")"

if [[ -n "${db_sgp_id}" && -n ${sgp_id} ]]
then
   granted="$(check_access_from_security_group_is_granted "${db_sgp_id}" "${DB_INST_PORT}" 'tcp' "${sgp_id}")"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_security_group "${db_sgp_id}" "${DB_INST_PORT}" 'tcp' "${sgp_id}"
   	
   	echo 'Access to database revoked.'
   fi
fi

## 
## Security group. 
## 
  
if [[ -n "${sgp_id}" ]]
then
   delete_security_group "${sgp_id}" 
      
   echo 'Admin security group deleted.'
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
   
   echo "Address released from the account." 
fi

## 
## SSH Access. 
## 

key_pair_file="$(get_keypair_file_path "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}")"

if [[ -f "${key_pair_file}" ]]
then
   delete_keypair "${key_pair_file}"
   
   echo 'The SSH access key-pair have been deleted.'
   echo
fi

## Clearing.
rm -rf "${TMP_DIR:?}"/admin

