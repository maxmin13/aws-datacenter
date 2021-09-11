#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

if [ "$#" -lt 1 ]; then
   echo "USAGE: webphp_id"
   echo "EXAMPLE: 1"
   echo "Only provided $# arguments"
   exit 1
fi

webphp_id="${1}"
export webphp_id="${1}"

echo '************'
echo "Webphp box ${webphp_id}" 
echo '************'
echo

webphp_nm="${WEBPHP_INST_NM/<ID>/"${webphp_id}"}"
keypair_nm="${WEBPHP_INST_KEY_PAIR_NM/<ID>/"${webphp_id}"}"
webphp_sgp_nm="${WEBPHP_INST_SEC_GRP_NM/<ID>/"${webphp_id}"}"
get_instance_id "${webphp_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Webphp box not found.'
else
   get_instance_state "${webphp_nm}"
   instance_st="${__RESULT}"
   
   echo "* Webphp box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${webphp_sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Webphp security group not found.'
else
   echo "* Webphp security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${webphp_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Webphp public IP address not found.'
else
   echo "* Webphp public IP address: ${eip}."
fi

get_security_group_id "${DB_INST_SEC_GRP_NM}"
db_sgp_id="${__RESULT}"

if [[ -z "${db_sgp_id}" ]]
then
   echo '* WARN: database security group not found.'
else
   echo "* database security group ID: ${db_sgp_id}."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
adm_sgp_id="${__RESULT}"

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

check_instance_is_registered_with_loadbalancer "${LBAL_INST_NM}" "${instance_id}"
is_registered="${__RESULT}"

if [[ 'true' == "${is_registered}" ]]
then
   deregister_instance_from_loadbalancer "${LBAL_INST_NM}" "${instance_id}"
fi

## 
## Webphp box 
## 

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${webphp_nm}"
   instance_st="${__RESULT}"

   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting Webphp box ..."
      
      delete_instance "${instance_id}" 'and_wait' > /dev/null
      
      echo 'Webphp box deleted.'
   fi
fi

## 
## Database grants 
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
## Admin box grants. 
## 

if [[ -n "${adm_sgp_id}" && -n ${sgp_id} ]]
then
   # Check if access to Admin rsyslog is granted.
   set +e
   revoke_access_from_security_group "${adm_sgp_id}" "${ADMIN_RSYSLOG_PORT}" 'tcp' "${sgp_id}" > /dev/null 2>&1
   set -e
   
   echo "Access to Admin Rsyslog revoked."

   # Check if the Webphp box is granted access to admin instance M/Monit
   set +e
   revoke_access_from_security_group "${adm_sgp_id}" "${ADMIN_MMONIT_COLLECTOR_PORT}" 'tcp' "${sgp_id}" > /dev/null 2>&1
   set -e
   
   echo "Access to Admin MMonit revoked."  
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
   get_allocation_id "${eip}"
   allocation_id="${__RESULT}" 
   
   if [[ -n "${allocation_id}" ]] 
   then
      release_public_ip_address "${allocation_id}"
   fi
   
   echo "Address released from the account." 
fi

## 
## SSH key-pair
## 

key_pair_file="$(get_local_keypair_file_path "${keypair_nm}" "${WEBPHP_INST_ACCESS_DIR}")"

if [[ -f "${key_pair_file}" ]]
then
   delete_local_keypair "${key_pair_file}"
   
   echo 'The SSH access key-pair have been deleted.'
   echo
fi

## Clearing
rm -rf "${TMP_DIR:?}"/webphp

