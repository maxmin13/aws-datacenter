#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

admin_dir='admin'

echo
echo '*********'
echo 'Admin box'
echo '*********'
echo

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Admin security group not found.'
else
   echo "* Admin security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Admin public IP address not found.'
else
   echo "* Admin public IP address: ${eip}."
fi

get_security_group_id "${DB_INST_SEC_GRP_NM}"
db_sgp_id="${__RESULT}"

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
rm -rf "${TMP_DIR:?}"/"${admin_dir}"

##
## Instance profile.
##

check_instance_profile_exists "${ADMIN_INST_PROFILE_NM}" > /dev/null
instance_profile_exists="${__RESULT}"

echo instance_profile_exists: $instance_profile_exists

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
      
      delete_instance "${instance_id}" 'and_wait' > /dev/null
      
      echo 'Admin box deleted.'
   fi
fi

## 
## Database grants. 
## 

get_security_group_id "${DB_INST_SEC_GRP_NM}"
db_sgp_id="${__RESULT}"

if [[ -n "${db_sgp_id}" && -n ${sgp_id} ]]
then
   set +e
   revoke_access_from_security_group "${db_sgp_id}" "${DB_INST_PORT}" 'tcp' "${sgp_id}" > /dev/null 2>&1
   set -e
   
   echo 'Access to database revoked.'
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
   get_allocation_id "${eip}"
   allocation_id="${__RESULT}" 
   
   if [[ -n "${allocation_id}" ]] 
   then
      release_public_ip_address "${allocation_id}"
   fi
   
   echo "Address released from the account." 
fi

##
## SSH keys.
##

check_aws_public_key_exists "${ADMIN_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'true' == "${key_exists}" ]]
then
   delete_aws_keypair "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}"
   
   echo 'The SSH access key-pair have been deleted.'
fi

## Clearing.
rm -rf "${TMP_DIR:?}"/"${admin_dir}"

