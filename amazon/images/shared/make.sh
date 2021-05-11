#!/usr/bin/bash

##########################################
# makes a secure linux box image, hardened
# and move ssh on 38142
# XGB EBS root volume.
# 'root', 'ec2-user', 'sudo' command are
# without password.
##########################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*****************'
echo 'Shared Base image'
echo '*****************'
echo

# 'ec2-user' and 'root' users and 'sudo' command 
# on the Shared image have no password.
# SSH port is 22, after the istance has been secured is 38142.

# Check if the shared image has already been created
ami_id="$(get_image_id "${SHARED_BASE_AMI_NM}")"

if [[ -n "${ami_id}" ]]
then
   echo "ERROR: The '${LBAL_NM}' AMI is already created'"
   exit 1
fi

vpc_id="$(get_vpc_id "${VPC_NM}")"
  
if [[ -z "${vpc_id}" ]]
then
   echo 'Error:  VPC not found.'
   exit 1
else
   echo "* VPC ID: '${vpc_id}'"
fi

subnet_id="$(get_subnet_id "${SUBNET_MAIN_NM}")"

if [[ -z "${subnet_id}" ]]
then
   echo 'Error:  Subnet not found.'
   exit 1
else
   echo "* Subnet ID: '${subnet_id}'"
fi

echo

## ************
## SSH Key Pair
## ************

# Delete the local private-key and the remote public-key.
delete_key_pair "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_ACCESS_DIR}"

# Create a key pair to SSH into the instance.
create_key_pair "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_ACCESS_DIR}"
echo 'Created a temporary Key Pair to connect to the Instance, the Private Key is saved in the credentias directory'

private_key="$(get_private_key_path "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_ACCESS_DIR}")"

## **************
## Security Group
## **************

my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
sg_id="$(get_security_group_id "${SHARED_BASE_INSTANCE_SEC_GRP_NM}")"

if [[ -n "${sg_id}" ]]
then
   echo 'ERROR: The Security Group is already created'
   exit 1
fi
  
sg_id="$(create_security_group "${vpc_id}" "${SHARED_BASE_INSTANCE_SEC_GRP_NM}" \
                        'Shared base instance security group')"

allow_access_from_cidr "${sg_id}" 22 "${my_ip}/32"
echo 'Created instance Security Group'

## ********************
## Shared Base instance
## ********************

instance_id="$(get_instance_id "${SHARED_BASE_INSTANCE_NM}")"

if [[ -n "${instance_id}" ]]; 
then
   echo "Error: Instance '${SHARED_BASE_INSTANCE_NM}' already created"
   exit 1
fi

echo "Creating '${SHARED_BASE_INSTANCE_NM}' instance ..."
run_base_instance "${sg_id}" "${subnet_id}"
instance_id="$(get_instance_id "${SHARED_BASE_INSTANCE_NM}")"
eip="$(get_public_ip_address_associated_with_instance "${SHARED_BASE_INSTANCE_NM}")"
echo "Instance public address: '${eip}'"

echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${eip}" 22 "${DEFAUT_AWS_USER}"

## ********
## Security 
## ********

# Send the security scripts to the instance

echo 'Uploading security scripts ...'

scp_upload_files "${private_key}" "${eip}" 22 "${DEFAUT_AWS_USER}" \
                 "${TEMPLATE_DIR}"/linux/secure-linux.sh \
                 "${TEMPLATE_DIR}"/linux/check-linux.sh \
                 "${TEMPLATE_DIR}"/linux/sshd_config \
                 "${TEMPLATE_DIR}"/linux/yumupdate.sh

echo 'Securing the Shared Base instance ...'

ssh_run_remote_command 'chmod +x secure-linux.sh' \
                   "${private_key}" \
                   "${eip}" \
                   22 \
                   "${DEFAUT_AWS_USER}" 

set +e
ssh_run_remote_command './secure-linux.sh' \
                   "${private_key}" \
                   "${eip}" \
                   22 \
                   "${DEFAUT_AWS_USER}"   
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then
   echo 'Rebooting instance ...'
   set +e
   ssh_run_remote_command 'reboot' \
                   "${private_key}" \
                   "${eip}" \
                   22 \
                   "${DEFAUT_AWS_USER}"
   set -e 
else
   echo 'Error: securing Linux instance'
   exit 1
fi


echo 'Shared Base instance successfully secured'
echo "SSH runs on '${SHARED_BASE_INSTANCE_SSH_PORT}' port"

revoke_access_from_cidr "${sg_id}" 22 "${my_ip}/32"
allow_access_from_cidr "${sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
echo "Security Group updated to allow access through '${SHARED_BASE_INSTANCE_SSH_PORT}' port"

eip="$(get_public_ip_address_associated_with_instance "${SHARED_BASE_INSTANCE_NM}")"
echo "Instance public address: '${eip}'"

echo 'Waiting for SSH to start in the instance'
wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

# Now SSH is on 38142

echo

ssh_run_remote_command 'chmod +x check-linux.sh' \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" 

echo 'Running security checks ...'

ssh_run_remote_command './check-linux.sh' \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"  
   
ssh_run_remote_command 'rm -f -R /home/ec2-user/*' \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"      

echo "Stopping '${SHARED_BASE_INSTANCE_NM}' instance ..."
stop_instance "${instance_id}"
echo "Instance '${SHARED_BASE_INSTANCE_NM}' stopped"

## *****************
## Shared Base image
## *****************

echo "Creating '${SHARED_BASE_AMI_NM}' Shared Base image ..."
create_image "${instance_id}" "${SHARED_BASE_AMI_NM}" "${SHARED_BASE_AMI_DESC}"	
echo "Shared Base image '${SHARED_BASE_AMI_NM}' created"

# Delete the Shared Base instance
instance_id="$(get_instance_id "${SHARED_BASE_INSTANCE_NM}")"
  
if [[ -z "${instance_id}" ]]
then
   echo "'${SHARED_BASE_INSTANCE_NM}' instance not found"
else
   instance_sts="$(get_instance_status "${SHARED_BASE_INSTANCE_NM}")"

   if [[ terminated == "${instance_sts}" ]]
   then
      echo "'${SHARED_BASE_INSTANCE_NM}' instance already deleted"
   else
      echo "Deleting '${SHARED_BASE_INSTANCE_NM}' instance ..."
      delete_instance "${instance_id}"
   fi
fi

## ********
## Key Pair
## ********

keypair_id="$(get_key_pair_id "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}")"

if [[ -z "${keypair_id}" ]]
then
   echo "The '${SHARED_BASE_INSTANCE_KEY_PAIR_NM}' Key Pair was not found"
else
   delete_key_pair "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" "${SHARED_BASE_INSTANCE_ACCESS_DIR}"
   echo "The '${SHARED_BASE_INSTANCE_KEY_PAIR_NM}' Key Pair has been deleted" 
fi

## **************
## Security Group
## **************

sg_id="$(get_security_group_id "${SHARED_BASE_INSTANCE_SEC_GRP_NM}")"
  
if [[ -z "${sg_id}" ]]
then
   echo "'${SHARED_BASE_INSTANCE_SEC_GRP_NM}' Security Group not found"
else
   delete_security_group "${sg_id}" 
   echo "'${SHARED_BASE_INSTANCE_SEC_GRP_NM}' Security Group deleted"
fi

echo 'Shared Base image created'
echo
