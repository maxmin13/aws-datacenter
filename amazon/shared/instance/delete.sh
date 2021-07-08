#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '**********'
echo 'Shared box'
echo '**********'
echo

shared_dir='shared'

# The temporary box used to build the image may already be gone
instance_id="$(get_instance_id "${SHARED_INST_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Shared box not found.'
else
   instance_st="$(get_instance_state "${SHARED_INST_NM}")"
   echo "* Shared box ID: ${instance_id} (${instance_st})."
fi

# The temporary security group used to build the image may already be gone
sgp_id="$(get_security_group_id "${SHARED_INST_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group. ${sgp_id}."
fi

echo

## 
## Shared box.
## 

if [[ -n "${instance_id}" ]]
then
   instance_st="$(get_instance_state "${SHARED_INST_NM}")"
   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo 'Deleting Shared box ...' 
      
      delete_instance "${instance_id}" 
      
      echo 'Shared box deleted.'
   fi
fi

## 
## security group 
## 
  
if [[ -n "${sgp_id}" ]]
then  
   # shellcheck disable=SC2015
   delete_security_group "${sgp_id}" 2> /dev/null && echo 'Security group deleted.' || 
   {
      __wait 60
      delete_security_group "${sgp_id}" 2> /dev/null && echo 'Security group deleted.' || 
      {
         __wait 60
         delete_security_group "${sgp_id}" 2> /dev/null && echo 'Security group deleted.' || 
         {
            echo 'Error: deleting security group.'
            exit 1
         }         
      } 
   }   
fi

## 
## Public IP 
## 

eip="$(get_public_ip_address_associated_with_instance "${SHARED_INST_NM}")"

if [[ -n "${eip}" ]]
then
   allocation_id="$(get_allocation_id "${eip}")"  
   
   if [[ -n "${allocation_id}" ]] 
   then
      release_public_ip_address "${allocation_id}"
   fi
   
   echo 'Address released from the account.' 
fi

## 
## SSH Key-pair
## 

key_pair_file="$(get_keypair_file_path "${SHARED_INST_KEY_PAIR_NM}" "${SHARED_INST_ACCESS_DIR}")"
   
if [[ -f "${key_pair_file}" ]]
then
   delete_keypair "${key_pair_file}"
   
   echo 'The SSH access key-pair have been deleted.'
   echo
fi

rm -rf "${TMP_DIR:?}"/"${shared_dir}"






















