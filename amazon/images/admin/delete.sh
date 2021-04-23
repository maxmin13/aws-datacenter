#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*********'
echo 'Admin box'
echo '*********'
echo
echo 'Deleting Admin box ...'

instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"
  
if [[ -z "${instance_id}" ]]
then
   echo "'${SERVER_ADMIN_NM}' Instance not found"
else
   instance_st="$(get_instance_status "${SERVER_ADMIN_NM}")"

   if [[ terminated == "${instance_st}" ]]
   then
      echo "'${SERVER_ADMIN_NM}' Instance not found"
   else
      echo "Deleting '${SERVER_ADMIN_NM}' Instance ..."
      delete_instance "${instance_id}"
      echo "'${SERVER_ADMIN_NM}' Instance deleted"
   fi
fi

## *** ##
## SSL ##
## *** ##

# Delete the local private-key and the remote public-key.
delete_key_pair "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_CREDENTIALS_DIR}" 
echo "The '${SERVER_ADMIN_KEY_PAIR_NM}' Key Pair has been deleted" 

## ******** ##
## Database ##
## ******** ##

adm_sg_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"
db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -z "${db_sg_id}" ]]
then
   echo "'${DB_MMDATA_SEC_GRP_NM}' Database Security Group not found"
else
   granted="$(check_access_from_group_is_granted "${db_sg_id}" "${DB_MMDATA_PORT}" "${adm_sg_id}")"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_security_group "${db_sg_id}" "${DB_MMDATA_PORT}" "${adm_sg_id}"
   	echo 'Revoked Database access to Admin box'
   else
   	echo 'Database access not found'
   fi
fi

## ************** ##
## Security Group ##
## ************** ##
  
if [[ -z "${adm_sg_id}" ]]
then
   echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group not found"
else
   delete_security_group "${adm_sg_id}"    
   echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group deleted"
fi

## ********* ##
## Public IP ##
## ******** ##

eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo "Admin public IP address found"
else
   allocation_id="$(get_allocation_id "${eip}")"   
   release_public_ip_address "${allocation_id}"
   echo "The '${eip}' public IP address was released from the account" 
fi

## ******** ##
## Clearing ##
## ******** ##

# Removing old files
rm -rf "${TMP_DIR}"/admin

echo 'Admin box deleted'
echo
