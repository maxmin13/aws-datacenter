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
instance_id="$(get_instance_id "${SHAR_INSTANCE_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Shared box not found.'
else
   echo "* Shared box ID: ${instance_id}."
fi

# The temporary Security Group used to build the image may already be gone
sgp_id="$(get_security_group_id "${SHAR_INSTANCE_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Security Group not found.'
else
   echo "* Security Group: ${sgp_id}."
fi

echo

## 
## Shared box.
## 

if [[ -n "${instance_id}" ]]
then
   instance_st="$(get_instance_state "${SHAR_INSTANCE_NM}")"
   if [[ 'terminated' == "${instance_st}" ]]
   then
      echo 'Shared box already deleted.'
   else
      echo 'Deleting Shared box ...' 
      
      delete_instance "${instance_id}"
      
      echo 'Shared box deleted.'
   fi
fi

## 
## Security Group 
## 
  
if [[ -n "${sgp_id}" ]]
then
   delete_security_group "${sgp_id}" 
      
   echo 'Shared box Security Group deleted.'
fi

## 
## Public IP 
## 

eip="$(get_public_ip_address_associated_with_instance "${SHAR_INSTANCE_NM}")"

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
## SSH access
## 

key_pair_file="$(get_keypair_file_path "${SHAR_INSTANCE_KEY_PAIR_NM}" "${SHAR_INSTANCE_ACCESS_DIR}")"
   
if [[ -f "${key_pair_file}" ]]
then
   delete_keypair "${key_pair_file}"
   
   echo 'The SSH access key-pair have been deleted.'
fi

rm -rf "${TMP_DIR:?}"/"${shared_dir}"

echo
echo 'Shared box deleted.'
echo





















