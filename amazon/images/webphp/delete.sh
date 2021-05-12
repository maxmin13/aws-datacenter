#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

if [[ $# -lt 1 ]]
then
   echo 'Error: Missing mandatory arguments'
   exit 1
else
   webphp_id="${1}"
   export webphp_id="${1}"
fi

webphp_nm="${SERVER_WEBPHP_NM/<ID>/${webphp_id}}"
webphp_instance_id="$(get_instance_id "${webphp_nm}")"
webphp_sg_nm="${SERVER_WEBPHP_SEC_GRP_NM/<ID>/${webphp_id}}"
webphp_sg_id="$(get_security_group_id "${webphp_sg_nm}")"

echo '************'
echo "WebPhp box ${webphp_id}" 
echo '************'
echo
echo 'Deleting Webphp box ...'

## ************* ##
## Load Balancer ##
## ************* ##

is_registered="$(check_instance_is_registered_with_loadbalancer "${LBAL_NM}" "${webphp_instance_id}")"

if [[ -z "${is_registered}" ]]
then
   echo "'${webphp_nm}' instance not registered with Load Balancer"
else
   echo "Deregistering '${webphp_nm}' from Load Balancer ..."
   deregister_instance_from_loadbalancer "${LBAL_NM}" "${webphp_instance_id}"
   echo 'Instance deregistered'
fi

## *************** ##
## WebPhp instance ##
## *************** ##

if [[ -z "${webphp_instance_id}" ]]
then
   echo "'${webphp_nm}' Instance not found"
else
   instance_st="$(get_instance_status "${webphp_nm}")"

   if [[ terminated == "${instance_st}" ]]
   then
      echo "'${webphp_nm}' Instance not found"
   else
      echo "Deleting '${webphp_nm}' Instance ..."
      delete_instance "${webphp_instance_id}"
      echo "'${webphp_nm}' Instance deleted"
   fi
fi

## *** ##
## SSH ##
## *** ##

key_pair_nm="${SERVER_WEBPHP_KEY_PAIR_NM/<ID>/${webphp_id}}"
 
# Delete the local private-key and the remote public-key.
delete_key_pair "${key_pair_nm}" "${WEBPHP_ACCESS_DIR}" 
echo "The '${key_pair_nm}' Key Pair has been deleted" 

## ******************** ##
## Grants from Database ##
## ******************** ##

db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -z "${db_sg_id}" ]]
then
   echo "'${DB_MMDATA_SEC_GRP_NM}' Database Security Group not found"
else
   # Check if Database access is granted
   granted="$(check_access_from_group_is_granted "${db_sg_id}" "${DB_MMDATA_PORT}" "${webphp_sg_id}")"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_security_group "${db_sg_id}" "${DB_MMDATA_PORT}" "${webphp_sg_id}"
   	echo 'Revoked access to Database'
   else
   	echo 'Access to Database not granted'
   fi
fi

## ***************** ##
## Grants from Admin ##
## ***************** ##

echo 'Removing grants from Admin instance ...'

adm_sgp_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -z "${adm_sgp_id}" ]]
then
   echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group not found"
else
   # Check if access to Admin Rsyslog is granted.
   rsyslog_granted="$(check_access_from_group_is_granted "${adm_sgp_id}" "${SERVER_ADMIN_RSYSLOG_PORT}" "${webphp_sg_id}")"
   
   if [[ -n "${rsyslog_granted}" ]]
   then
   	revoke_access_from_security_group "${adm_sgp_id}" "${SERVER_ADMIN_RSYSLOG_PORT}" "${webphp_sg_id}"
   	echo "Revoked access to Admin server rsyslog"
   else
   	echo 'Access to Admin server rsyslog not granted'
   fi

   # Check if WebPhp instance is granted access to Admin instance M/Monit
   mmonit_granted="$(check_access_from_group_is_granted "${adm_sgp_id}" "${SERVER_ADMIN_MMONIT_COLLECTOR_PORT}" "${webphp_sg_id}")"
   
   if [[ -n "${mmonit_granted}" ]]
   then
   	revoke_access_from_security_group "${adm_sgp_id}" "${SERVER_ADMIN_MMONIT_COLLECTOR_PORT}" "${webphp_sg_id}"
   	echo "Revoked access to Admin server MMonit"
   else
   	echo 'Access to Admin server MMonit not found'
   fi   
fi

## ************** ##
## Security Group ##
## ************** ##
  
if [[ -z "${webphp_sg_id}" ]]
then
   echo "'${webphp_sg_nm}' WebPhp Security Group not found"
else
   delete_security_group "${webphp_sg_id}"    
   echo "'${webphp_sg_nm}' WebPhp Security Group deleted"
fi

## ********* ##
## Public IP ##
## ********* ##

eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${eip}" ]]
then
   echo "No public IP address found associated with '${webphp_nm}'"
else
   allocation_id="$(get_allocation_id "${eip}")"   
   release_public_ip_address "${allocation_id}"
   echo "The '${eip}' public IP address was released from the account" 
fi

## ******** ##
## Clearing ##
## ******** ##

# Removing old files
rm -rf "${TMP_DIR:?}"/webphp

echo 'WebPhp box deleted'
echo
