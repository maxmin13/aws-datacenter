#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '**************************'
echo 'Deleting Base instance ...'
echo '**************************'
echo

# Try to delete the temporary Instance used to create the shared image, if still there
instance_id="$(get_instance_id "${SHARED_BASE_INSTANCE_NM}")"
  
if [[ -z "${instance_id}" ]]
then
   echo "'${SHARED_BASE_INSTANCE_NM}' Instance not found"
else
   instance_st="$(get_instance_status "${SHARED_BASE_INSTANCE_NM}")"

   if [[ terminated == "${instance_st}" ]]
   then
      echo "'${SHARED_BASE_INSTANCE_NM}' Instance already deleted"
   else
      echo "Deleting '${SHARED_BASE_INSTANCE_NM}' Instance ..." 
      delete_instance "${instance_id}"
      echo "'${SHARED_BASE_INSTANCE_NM}' Instance deleted"
   fi
fi

## *********************************
## Delete Shared Image and Snapshots
## *********************************

img_id="$(get_image_id "${SHARED_BASE_AMI_NM}")"

# Get the snapshot IDs before deleting the image.
img_snapshot_ids="$(get_image_snapshot_ids "${SHARED_BASE_AMI_NM}")"

if [[ -z "${img_id}" ]]
then
   echo "'${SHARED_BASE_AMI_NM}' Shared Image not found"
else
   delete_image "${img_id}" 
   echo "'${SHARED_BASE_AMI_NM}' Shared Image deleted"
fi

if [[ -z "${img_snapshot_ids}" ]]
then
   echo 'No Image Snapshots found'
else
   for id in ${img_snapshot_ids}
   do
      delete_image_snapshot "${id}"
      echo "Snapshot '${id}' deleted"
   done
fi

## ***************
## Delete Key Pair
## ***************

# Delete the local private-key and the remote public-key.
delete_key_pair "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_CREDENTIALS_DIR}"

## *********************
## Delete Security Group
## *********************

# Try to delete the temporary security group used to create the shared image, if still there
sg_id="$(get_security_group_id "${SHARED_BASE_INSTANCE_SEC_GRP_NM}")"
  
if [[ -z "${sg_id}" ]]
then
   echo "'${SHARED_BASE_INSTANCE_SEC_GRP_NM}' Security Group not found"
else
   delete_security_group "${sg_id}"    
   echo "'${SHARED_BASE_INSTANCE_SEC_GRP_NM}' Security Group deleted"
fi

echo 'Linux shared Image deleted'
echo

