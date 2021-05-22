#!/usr/bin/bash

##########################################
# makes a secure linux box image:
# hardened, ssh on 38142.
# no root access.
# ec2-user sudo command doesn't have 
# password.
##########################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*****************'
echo 'Shared base image'
echo '*****************'
echo


# Check if the shared base image has already been created
image_id="$(get_image_id "${SHARED_BASE_AMI_NM}")"

if [[ -n "${image_id}" ]]
then
   echo '* ERROR: the shared base image is already created'
   exit 1
fi

vpc_id="$(get_vpc_id "${VPC_NM}")"
  
if [[ -z "${vpc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: '${vpc_id}'"
fi

subnet_id="$(get_subnet_id "${SUBNET_MAIN_NM}")"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: '${subnet_id}'"
fi

echo

## 
## SSH access key pair
## 

# Create a key pair to SSH into the instance.
  create_key_pair "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_ACCESS_DIR}"
echo 'Created a temporary Key Pair to connect to the Instance, the Private Key is saved in the credentias directory'

private_key="$(get_private_key_path "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_ACCESS_DIR}")"

## 
## Security group
##

my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
sg_id="$(get_security_group_id "${SHARED_BASE_INSTANCE_SEC_GRP_NM}")"

if [[ -n "${sg_id}" ]]
then
   echo 'ERROR: the security group is already created'
   exit 1
fi
  
sg_id="$(create_security_group "${vpc_id}" "${SHARED_BASE_INSTANCE_SEC_GRP_NM}" \
                        'Shared base instance security group')"

allow_access_from_cidr "${sg_id}" 22 "0.0.0.0/0"
##### allow_access_from_cidr "${sg_id}" 22 "${my_ip}/32"
echo 'Created instance security group'

## 
## Shared base instance
## 

instance_id="$(get_instance_id "${SHARED_BASE_INSTANCE_NM}")"

if [[ -n "${instance_id}" ]]; 
then
   echo 'ERROR: shared base instance already created'
   exit 1
fi

echo "Creating the shared base instance ..."
run_base_instance "${sg_id}" "${subnet_id}"
instance_id="$(get_instance_id "${SHARED_BASE_INSTANCE_NM}")"
eip="$(get_public_ip_address_associated_with_instance "${SHARED_BASE_INSTANCE_NM}")"
echo "Shared base instance public address: '${eip}'"

echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${eip}" 22 "${DEFAUT_AWS_USER}"

## 
## Security 
## 

# Upload the security scripts to the instance

echo 'Uploading scripts to the shared base instance ...'
remote_dir=/home/ec2-user/script

## 
## Remote commands that have to be executed as priviledged user are run with sudo.
## By AWS default, sudo has not password.
##  

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
                 "${private_key}" \
                 "${eip}" \
                 22 \
                 "${DEFAUT_AWS_USER}"  

scp_upload_files "${private_key}" "${eip}" 22 "${DEFAUT_AWS_USER}" "${remote_dir}" \
                 "${TEMPLATE_DIR}"/linux/secure-linux.sh \
                 "${TEMPLATE_DIR}"/linux/check-linux.sh \
                 "${TEMPLATE_DIR}"/linux/sshd_config \
                 "${TEMPLATE_DIR}"/linux/yumupdate.sh

echo 'Securing the shared base instance ...'

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/secure-linux.sh" \
                 "${private_key}" \
                 "${eip}" \
                 22 \
                 "${DEFAUT_AWS_USER}" \
                 
set +e
ssh_run_remote_command_as_root "${remote_dir}/secure-linux.sh" \
                 "${private_key}" \
                 "${eip}" \
                 22 \
                 "${DEFAUT_AWS_USER}" 
                   
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then
   echo 'Rebooting the instance ...'
   set +e
   ssh_run_remote_command_as_root 'reboot' \
                 "${private_key}" \
                 "${eip}" \
                 22 \
                 "${DEFAUT_AWS_USER}"
   set -e 
else
   echo 'ERROR: securing the shared base instance'
   exit 1
fi

echo 'Shared base instance successfully secured'
echo "SSH on '${SHARED_BASE_INSTANCE_SSH_PORT}' port"

##### revoke_access_from_cidr "${sg_id}" 22 "${my_ip}/32"
#####allow_access_from_cidr "${sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
allow_access_from_cidr "${sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
echo "Instance security group updated to allow access through '${SHARED_BASE_INSTANCE_SSH_PORT}' port"

eip="$(get_public_ip_address_associated_with_instance "${SHARED_BASE_INSTANCE_NM}")"
echo "Instance public address: '${eip}'"

echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/check-linux.sh" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"

echo 'Running security checks in the instance ...'

ssh_run_remote_command_as_root "${remote_dir}/check-linux.sh" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"  
   
# Clear remote directory.
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"      

echo 'Stopping the shared base instance ...'
stop_instance "${instance_id}"
echo 'Shared base instance stopped'

## 
## Shared base image
## 

echo 'Creating a shared base image ...'
create_image "${instance_id}" "${SHARED_BASE_AMI_NM}" "${SHARED_BASE_AMI_DESC}"	
echo 'Shared base image created'

# Delete the Shared Base instance
instance_id="$(get_instance_id "${SHARED_BASE_INSTANCE_NM}")"
  
if [[ -n "${instance_id}" ]]
then
   echo 'Deleting shared base instance ...'
   instance_sts="$(get_instance_status "${SHARED_BASE_INSTANCE_NM}")"

   if [[ 'terminated' == "${instance_sts}" ]]
   then
      echo 'Shared base instance alredy deleted'
   else
      delete_instance "${instance_id}"
      echo 'Shared base instance deleted'
   fi
fi

## 
## SSH access key pair
## 

keypair_id="$(get_key_pair_id "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}")"

if [[ -n "${keypair_id}" ]]
then
   delete_key_pair "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_ACCESS_DIR}"
   echo 'The SSH access key pair have been deleted'
fi

## 
## Security group
##

sg_id="$(get_security_group_id "${SHARED_BASE_INSTANCE_SEC_GRP_NM}")"
  
if [[ -n "${sg_id}" ]]
then
   delete_security_group "${sg_id}" 
   echo 'Security group deleted'
fi

echo 'Shared base image created'
echo
