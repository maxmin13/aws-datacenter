#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '************'
echo 'Shared image'
echo '************'
echo

shared_dir='shared'

# The temporary box used to build the image, it should be already deleted.
get_instance_id "${SHARED_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Shared box not found.'
else
   instance_st="$(get_instance_state "${SHARED_INST_NM}")"
   echo "* Shared box ID: ${instance_id} (${instance_st})."
fi

# The temporary security group used to build the image, it should be already deleted.
sgp_id="$(get_security_group_id "${SHARED_INST_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group. ${sgp_id}."
fi

image_id="$(get_image_id "${SHARED_IMG_NM}")"

if [[ -z "${image_id}" ]]
then
   echo '* WARN: Shared image not found.'
else
   echo "* Shared image ID: ${image_id}."
fi

snapshot_ids="$(get_image_snapshot_ids "${SHARED_IMG_NM}")"

if [[ -z "${snapshot_ids}" ]]
then
   echo '* WARN: Shared image snapshots not found.'
else
   echo "* Shared image snapshot IDs: ${snapshot_ids}."
fi

echo

## 
## Shared image.
## 

if [[ -n "${image_id}" ]]
then
   echo 'Deleting Shared image ...'
   
   delete_image "${image_id}" 
   
   echo 'Shared image deleted.'
fi

## 
## Image snapshots.
##

if [[ -n "${snapshot_ids}" ]]
then
   for id in ${snapshot_ids}
   do
      echo "Deleting snapshot ..."
      
      delete_image_snapshot "${id}"
      
      echo 'Snapshot deleted.'
      echo
   done
fi



