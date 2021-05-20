#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*****************'
echo 'Shared Base Image'
echo '*****************'
echo

# The temporary instance used to build the image may already be gone
shared_instance_id="$(get_instance_id "${SHARED_BASE_INSTANCE_NM}")"

if [[ -z "${shared_instance_id}" ]]
then
   echo '* WARN: shared base instance not found'
else
   echo "* shared base instance ID: '${shared_instance_id}'"
fi

# The temporary security group used to build the image may already be gone
sg_id="$(get_security_group_id "${SHARED_BASE_INSTANCE_SEC_GRP_NM}")"

if [[ -z "${sg_id}" ]]
then
   echo '* WARN: security group not found'
else
   echo "* security group: '${sg_id}'"
fi

shared_image_id="$(get_image_id "${SHARED_BASE_AMI_NM}")"

if [[ -z "${shared_image_id}" ]]
then
   echo '* WARN: shared base image not found'
else
   echo "* shared base image ID: '${shared_image_id}'"
fi

shared_image_snapshot_ids="$(get_image_snapshot_ids "${SHARED_BASE_AMI_NM}")"

if [[ -z "${shared_image_snapshot_ids}" ]]
then
   echo '* WARN: shared base image snapshots not found'
else
   echo "* shared base image snapshot IDs: '${shared_image_snapshot_ids}'"
fi

echo

## 
## Delete shared base instance.
## 

if [[ -n "${shared_instance_id}" ]]
then
   instance_st="$(get_instance_status "${SHARED_BASE_INSTANCE_NM}")"
   if [[ 'terminated' == "${instance_st}" ]]
   then
      echo 'Shared base instance already deleted'
   else
      echo 'Deleting shared base instance ...' 
      delete_instance "${shared_instance_id}"
      echo 'Shared base instance deleted'
   fi
fi

## 
## Delete shared base image and snapshots.
## 

if [[ -n "${shared_image_id}" ]]
then
   echo 'Deleting shared base image ...'
   delete_image "${shared_image_id}" 
   echo 'Shared base image deleted'
fi

if [[ -n "${shared_image_snapshot_ids}" ]]
then
   for id in ${shared_image_snapshot_ids}
   do
      echo "Deleting ${id} snapshot .."
      delete_image_snapshot "${id}"
      echo 'Snapshot deleted'
   done
fi

## 
## Delete the access key pair
## 

# Delete the local private-key and the remote public-key.
delete_key_pair "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_ACCESS_DIR}"

## 
## Delete security group
## 

if [[ -n "${sg_id}" ]]
then
   delete_security_group "${sg_id}"    
   echo 'Security group deleted'
fi

echo

