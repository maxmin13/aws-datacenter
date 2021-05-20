#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

if [[ $# -lt 1 ]]
then
   echo '* ERROR: Missing mandatory arguments'
   exit 1
else
   webphp_id="${1}"
   export webphp_id="${1}"
fi

echo '************'
echo "WebPhp box ${webphp_id}" 
echo '************'
echo

webphp_nm="${SERVER_WEBPHP_NM/<ID>/${webphp_id}}"
webphp_instance_id="$(get_instance_id "${webphp_nm}")"

if [[ -z "${webphp_instance_id}" ]]
then
   echo '* WARN: webphp instance not found'
else
   echo "* webphp instance ID: '${webphp_instance_id}'"
fi

webphp_sg_nm="${SERVER_WEBPHP_SEC_GRP_NM/<ID>/${webphp_id}}"
webphp_sg_id="$(get_security_group_id "${webphp_sg_nm}")"

if [[ -z "${webphp_sgp_id}" ]]
then
   echo '* WARN: webphp security group not found'
else
   echo "* webphp security group ID: '${webphp_sgp_id}'"
fi

eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: webphp public IP address not found'
else
   echo "* webphp public IP address: '${eip}'"
fi

db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -z "${db_sg_id}" ]]
then
   echo '* WARN: database security group not found'
else
   echo "* database security group ID: '${db_sg_id}'"
fi

adm_sgp_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -z "${adm_sgp_id}" ]]
then
   echo '* WARN: admin security group not found'
else
   echo "* admin security group ID: '${adm_sgp_id}'"
fi

is_registered_with_loadbalancer="$(check_instance_is_registered_with_loadbalancer "${LBAL_NM}" "${webphp_instance_id}")"

if [[ -z "${is_registered_with_loadbalancer}" ]]
then
   echo '* WARN: the webphp instance in not registered with the load balancer'
else
   echo '* the webphp instance in registered with the load balancer'
fi

echo

## 
## Clearing local files
## 
rm -rf "${TMP_DIR:?}"/webphp

## 
## Unregister the instance from the load balancer.
## 

if [[ -n "${is_registered_with_loadbalancer}" ]]
then
   echo 'Deregistering the instance from the load balancer ...'
   deregister_instance_from_loadbalancer "${LBAL_NM}" "${webphp_instance_id}"
   echo 'Instance deregistered from the load balancer'
fi

## 
## WebPhp instance 
## 

if [[ -n "${webphp_instance_id}" ]]
then
   instance_st="$(get_instance_status "${webphp_nm}")"

   if [[ 'terminated' == "${instance_st}" ]]
   then
      echo 'Instance status is terminated'
   else
      echo "Deleting '${webphp_nm}' Instance ..."
      delete_instance "${webphp_instance_id}"
      echo 'Instance deleted'
   fi
fi

## 
## Deleting access keys
## 

# Delete the local private-key and the remote public-key.
key_pair_nm="${SERVER_WEBPHP_KEY_PAIR_NM/<ID>/${webphp_id}}"
delete_key_pair "${key_pair_nm}" "${WEBPHP_ACCESS_DIR}" 
echo 'The SSH access keys have been deleted' 

## 
## Remove grants to access the database from the instance. 
## 

db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -n "${db_sg_id}" && -n ${webphp_sg_id} ]]
then
   granted="$(check_access_from_group_is_granted "${db_sg_id}" "${DB_MMDATA_PORT}" "${webphp_sg_id}")"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_security_group "${db_sg_id}" "${DB_MMDATA_PORT}" "${webphp_sg_id}"
   	echo 'Revoked access to database'
   else
   	echo 'Access to database was not granted'
   fi
fi

## 
## Remove grants to access admin server from the instance. 
## 

if [[ -n "${adm_sgp_id}" && -n ${webphp_sg_id} ]]
then
   # Check if access to admin rsyslog is granted.
   rsyslog_granted="$(check_access_from_group_is_granted "${adm_sgp_id}" "${SERVER_ADMIN_RSYSLOG_PORT}" "${webphp_sg_id}")"
   
   if [[ -n "${rsyslog_granted}" ]]
   then
   	revoke_access_from_security_group "${adm_sgp_id}" "${SERVER_ADMIN_RSYSLOG_PORT}" "${webphp_sg_id}"
   	echo "Revoked access to admin server Rsyslog"
   else
   	echo 'Access to admin server Rsyslog not granted'
   fi

   # Check if webphp instance is granted access to admin instance M/Monit
   mmonit_granted="$(check_access_from_group_is_granted "${adm_sgp_id}" "${SERVER_ADMIN_MMONIT_COLLECTOR_PORT}" "${webphp_sg_id}")"
   
   if [[ -n "${mmonit_granted}" ]]
   then
   	revoke_access_from_security_group "${adm_sgp_id}" "${SERVER_ADMIN_MMONIT_COLLECTOR_PORT}" "${webphp_sg_id}"
   	echo "Revoked access to admin server MMonit"
   else
   	echo 'Access to admin server MMonit not found'
   fi   
fi

##
## Security Group 
##
  
if [[ -n "${webphp_sg_id}" ]]
then
   delete_security_group "${webphp_sg_id}"    
   echo 'Webphp security group deleted'
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

rm -rf "${TMP_DIR:?}"/webphp

echo
