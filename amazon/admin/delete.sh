#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*********'
echo 'Admin box'
echo '*********'
echo

admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* WARN: admin instance not found'
else
   echo "* admin instance ID: '${admin_instance_id}'"
fi

adm_sgp_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -z "${adm_sgp_id}" ]]
then
   echo '* WARN: admin security group not found'
else
   echo "* admin security group ID: '${adm_sgp_id}'"
fi

eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: admin public IP address not found'
else
   echo "* admin public IP address: '${eip}'"
fi

db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -z "${db_sg_id}" ]]
then
   echo '* WARN: database security group not found'
else
   echo "* database security group ID: '${db_sg_id}'"
fi

echo

## 
## Clearing local files
## 
rm -rf "${TMP_DIR:?}"/admin

##
## Admin instance 
## 

if [[ -n "${admin_instance_id}" ]]
then
   instance_st="$(get_instance_status "${SERVER_ADMIN_NM}")"

   if [[ 'terminated' == "${instance_st}" ]]
   then
      echo 'Instance status is terminated'
   else
      echo "Deleting the instance ..."
      delete_instance "${admin_instance_id}"
      echo 'Instance deleted'
   fi
fi

## 
## Deleting access keys
## 

# Delete the local private-key and the remote public-key.
delete_key_pair "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}" 
echo 'The SSH access keys have been deleted'

## 
## Remove grants to access the database from the instance. 
## 

db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -n "${db_sg_id}" && -n ${adm_sgp_id} ]]
then
   granted="$(check_access_from_group_is_granted "${db_sg_id}" "${DB_MMDATA_PORT}" "${adm_sgp_id}")"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_security_group "${db_sg_id}" "${DB_MMDATA_PORT}" "${adm_sgp_id}"
   	echo 'Revoked access to database'
   else
   	echo 'Access to database was not granted'
   fi
fi

## 
## Security Group 
## 
  
if [[ -n "${adm_sgp_id}" ]]
then
   delete_security_group "${adm_sgp_id}"    
   echo 'Admin security group deleted'
fi

## 
## Public IP 
## 

if [[ -n "${eip}" ]]
then
   allocation_id="$(get_allocation_id "${eip}")"   
   release_public_ip_address "${allocation_id}"
   echo "The '${eip}' public IP address was released from the account" 
fi

##
## Clearing
## 
rm -rf "${TMP_DIR:?}"/admin

echo
