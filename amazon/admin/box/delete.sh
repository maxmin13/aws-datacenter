#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*********'
echo 'Admin box'
echo '*********'
echo

instance_id="$(get_instance_id "${SRV_ADMIN_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   echo "* Admin box ID: ${instance_id}."
fi

sgp_id="$(get_security_group_id "${SRV_ADMIN_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Admin Security Group not found.'
else
   echo "* Admin Security Group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${SRV_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Admin public IP address not found.'
else
   echo "* Admin public IP address: ${eip}."
fi

db_sgp_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -z "${db_sgp_id}" ]]
then
   echo '* WARN: Database Security Group not found.'
else
   echo "* Database Security Group ID: ${db_sgp_id}."
fi

echo

## 
## Clearing local files
## 
rm -rf "${TMP_DIR:?}"/admin

##
## Admin box 
## 

if [[ -n "${instance_id}" ]]
then
   instance_st="$(get_instance_state "${SRV_ADMIN_NM}")"

   if [[ 'terminated' == "${instance_st}" ]]
   then
      echo 'Instance status is terminated.'
   else
      echo "Deleting Admin box ..."
      
      delete_instance "${instance_id}"
      
      echo 'Admin box deleted.'
   fi
fi

## 
## Database grants 
## 

db_sgp_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -n "${db_sgp_id}" && -n ${sgp_id} ]]
then
   granted="$(check_access_from_security_group_is_granted "${db_sgp_id}" "${DB_MMDATA_PORT}" "${sgp_id}")"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_security_group "${db_sgp_id}" "${DB_MMDATA_PORT}" "${sgp_id}"
   	
   	echo 'Access to Database revoked.'
   fi
fi

## 
## Security Group 
## 
  
if [[ -n "${sgp_id}" ]]
then
   delete_security_group "${sgp_id}" 
      
   echo 'Admin Security Group deleted.'
fi

## 
## Public IP 
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
## SSH Access 
## 

key_pair_file="$(get_keypair_file_path "${SRV_ADMIN_KEY_PAIR_NM}" "${SRV_ADMIN_ACCESS_DIR}")"

if [[ -f "${key_pair_file}" ]]
then
   delete_keypair "${key_pair_file}"
   
   echo 'The SSH access key-pair have been deleted.'
fi

## Clearing
rm -rf "${TMP_DIR:?}"/admin

echo
echo 'Admin box deleted.'
echo
