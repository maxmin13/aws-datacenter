#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

if [[ $# -lt 1 ]]
then
   echo '* ERROR: missing mandatory arguments..'
   exit 1
else
   webphp_id="${1}"
   export webphp_id="${1}"
fi

echo '************'
echo "Webphp box ${webphp_id}" 
echo '************'
echo

webphp_nm="${WEBPHP_INST_NM/<ID>/"${webphp_id}"}"
keypair_nm="${WEBPHP_INST_KEY_PAIR_NM/<ID>/"${webphp_id}"}"
webphp_sgp_nm="${WEBPHP_INST_SEC_GRP_NM/<ID>/"${webphp_id}"}"
instance_id="$(get_instance_id "${webphp_nm}")"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Webphp box not found.'
else
   instance_st="$(get_instance_state "${webphp_nm}")"
   echo "* Webphp box ID: ${instance_id} (${instance_st})."
fi

sgp_id="$(get_security_group_id "${webphp_sgp_nm}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Webphp security group not found.'
else
   echo "* Webphp security group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Webphp public IP address not found.'
else
   echo "* Webphp public IP address: ${eip}."
fi

db_sgp_id="$(get_security_group_id "${DB_INST_SEC_GRP_NM}")"

if [[ -z "${db_sgp_id}" ]]
then
   echo '* WARN: database security group not found.'
else
   echo "* database security group ID: ${db_sgp_id}."
fi

adm_sgp_id="$(get_security_group_id "${ADMIN_INST_SEC_GRP_NM}")"

if [[ -z "${adm_sgp_id}" ]]
then
   echo '* WARN: admin security group not found.'
else
   echo "* Admin security group ID: ${adm_sgp_id}."
fi

echo

## Clearing local files
rm -rf "${TMP_DIR:?}"/webphp

## 
## Load balancer 
## 

is_registered="$(check_instance_is_registered_with_loadbalancer "${LBAL_INST_NM}" "${instance_id}")"

if [[ 'true' == "${is_registered}" ]]
then
   deregister_instance_from_loadbalancer "${LBAL_INST_NM}" "${instance_id}"
fi

## 
## Webphp box 
## 

if [[ -n "${instance_id}" ]]
then
   instance_st="$(get_instance_state "${webphp_nm}")"

   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting Webphp box ..."
      
      delete_instance "${instance_id}" 'and_wait'
      
      echo 'Webphp box deleted.'
   fi
fi

## 
## Database grants 
## 

db_sgp_id="$(get_security_group_id "${DB_INST_SEC_GRP_NM}")"

if [[ -n "${db_sgp_id}" && -n ${sgp_id} ]]
then
   granted="$(check_access_from_security_group_is_granted "${db_sgp_id}" "${DB_INST_PORT}" "${sgp_id}")"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_security_group "${db_sgp_id}" "${DB_INST_PORT}" "${sgp_id}"
   	
   	echo 'Access to database revoked.'
   fi
fi

## 
## Admin box grants. 
## 

if [[ -n "${adm_sgp_id}" && -n ${sgp_id} ]]
then
   # Check if access to Admin rsyslog is granted.
   rsyslog_granted="$(check_access_from_security_group_is_granted "${adm_sgp_id}" "${ADMIN_RSYSLOG_PORT}" "${sgp_id}")"
   
   if [[ -n "${rsyslog_granted}" ]]
   then
   	revoke_access_from_security_group "${adm_sgp_id}" "${ADMIN_RSYSLOG_PORT}" "${sgp_id}"
   	
   	echo "Access to Admin Rsyslog revoked."
   fi

   # Check if the Webphp box is granted access to admin instance M/Monit
   mmonit_granted="$(check_access_from_security_group_is_granted "${adm_sgp_id}" "${ADMIN_MMONIT_COLLECTOR_PORT}" "${sgp_id}")"
   
   if [[ -n "${mmonit_granted}" ]]
   then
   	revoke_access_from_security_group "${adm_sgp_id}" "${ADMIN_MMONIT_COLLECTOR_PORT}" "${sgp_id}"
   	
   	echo "Access to Admin MMonit revoked."
   fi   
fi

## 
## Security group 
## 
  
if [[ -n "${sgp_id}" ]]
then
   delete_security_group "${sgp_id}" 
      
   echo 'Webphp security group deleted.'
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
## SSH key-pair
## 

key_pair_file="$(get_keypair_file_path "${keypair_nm}" "${WEBPHP_INST_ACCESS_DIR}")"

if [[ -f "${key_pair_file}" ]]
then
   delete_keypair "${key_pair_file}"
   
   echo 'The SSH access key-pair have been deleted.'
   echo
fi

## Clearing
rm -rf "${TMP_DIR:?}"/webphp

