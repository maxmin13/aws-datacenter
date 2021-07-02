#!/usr/bin/bash

##########################################
# makes a secure linux box image:
# hardened, ssh on 38142.
# No root access to the instance.
# Remove the ec2-user default user and 
# creates the shared-user user.
##########################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '************'
echo 'Shared image'
echo '************'
echo

shared_dir='shared'

dtc_id="$(get_datacenter_id "${DTC_NM}")"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

image_id="$(get_image_id "${SHARED_IMG_NM}")"

if [[ -n "${image_id}" ]]
then
   image_state="$(get_image_state "${SHARED_IMG_NM}")"
   
   if [[ 'available' == "${image_state}" ]]
   then
      echo "* WARN: the image is already created (${image_state})"
      echo
      return
   else
      # This is the case the image is in 'terminated' state, it takes about an hour to disappear,
      # if you want to create a new image you have to change the name.
      echo "* ERROR: the image is already created (${image_state})" 
      exit 1  
   fi
fi

# Create an image based on an previously created instance.
# Amazon EC2 powers down the instance before creating the AMI to ensure that everything on the 
# instance is stopped and in a consistent state during the creation process.

instance_id="$(get_instance_id "${SHARED_BOX_NM}")"
instance_state="$(get_instance_state "${SHARED_BOX_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Shared box not found.'
   exit 1
else
   echo "* Shared box ID: ${instance_id} (${instance_state})."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"
mkdir "${TMP_DIR}"/"${shared_dir}"

## 
## Shared image.
## 

echo 'Creating the Shared image ...'

create_image "${instance_id}" "${SHARED_IMG_NM}" "${SHARED_IMG_DESC}" >> /dev/null	

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"

echo
echo 'Shared image created.'
echo
