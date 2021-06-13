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
instance_id="$(get_instance_id "${SHAR_INSTANCE_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Shared box not found.'
else
   echo "* Shared box ID: ${instance_id}."
fi

# The temporary Security Group used to build the image, it should be already deleted.
sgp_id="$(get_security_group_id "${SHAR_INSTANCE_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Security Group not found.'
else
   echo "* Security Group: ${sgp_id}."
fi

image_id="$(get_image_id "${SHAR_IMAGE_NM}")"

if [[ -z "${image_id}" ]]
then
   echo '* WARN: Shared image not found.'
else
   echo "* Shared image ID: ${image_id}."
fi

snapshot_ids="$(get_image_snapshot_ids "${SHAR_IMAGE_NM}")"

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
   done
fi

echo
echo 'Shared image deleted'
echo


