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

echo '**********'
echo 'Shared box'
echo '**********'
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

subnet_id="$(get_subnet_id "${DTC_SUBNET_MAIN_NM}")"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${subnet_id}."
fi

image_id="$(get_image_id "${SHARED_IMG_NM}")"

if [[ -z "${image_id}" ]]
then
   echo '* WARN: Shared image not found.'
else
   image_state="$(get_image_state "${SHARED_IMG_NM}")"
   echo "* Shared image ID: ${image_id} (${image_state})."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"
mkdir "${TMP_DIR}"/"${shared_dir}"

## 
## Security group
##

sgp_id="$(get_security_group_id "${SHARED_INST_SEC_GRP_NM}")"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Shared security group is already created.'
else
   sgp_id="$(create_security_group "${dtc_id}" "${SHARED_INST_SEC_GRP_NM}" 'Shared security group.')"  

   echo 'Created Shared security group.'
fi

granted_ssh_22="$(check_access_from_cidr_is_granted  "${sgp_id}" '22' 'tcp' '0.0.0.0/0')"

if [[ -z "${granted_ssh_22}" ]]
then
   allow_access_from_cidr "${sgp_id}" '22' 'tcp' '0.0.0.0/0'
   
   echo 'Granted SSH access on port 22.'
fi

granted_ssh_38142="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0')"

if [[ -z "${granted_ssh_38142}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   
   echo "Granted SSH access on port ${SHARED_INST_SSH_PORT}."
fi

##
## Cloud init
##   

## Removes the default user, creates the admin-user user and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${SHARED_INST_USER_PWD}")" 
key_pair_file="$(get_keypair_file_path "${SHARED_INST_KEY_PAIR_NM}" "${SHARED_INST_ACCESS_DIR}")"

if [[ -f "${key_pair_file}" ]]
then
   echo 'WARN: SSH key-pair already created.'
else
   # Save the private key file in the access directory
   mkdir -p "${SHARED_INST_ACCESS_DIR}"
   generate_keypair "${key_pair_file}" "${ADMIN_INST_EMAIL}" 
      
   echo 'SSH key-pair created.'
fi

public_key="$(get_public_key "${key_pair_file}")"
 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${SHARED_INST_USER_NM}" -v hostname="${SHARED_INST_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${TEMPLATE_DIR}"/common/cloud-init/cloud_init_template.yml > "${TMP_DIR}"/"${shared_dir}"/cloud_init.yml
  
echo 'cloud_init.yml ready.'  

## 
## Shared box
## 

instance_id="$(get_instance_id "${SHARED_INST_NM}")"
instance_state="$(get_instance_state "${SHARED_INST_NM}")"

if [[ -n "${image_id}" && 'available' == "${image_state}" ]]
then    
   echo 'Shared image already created, skipping creating Shared box.'
   echo
   return
   
elif [[ -n "${instance_id}" ]]
then
   if [[ 'running' == "${instance_state}" || 'stopped' == "${instance_state}" ]]
   then
      echo "WARN: Shared box already created (${instance_state})."
      echo
      return
   else
      # An istance lasts in terminated status for about an hour, before that change name.
      echo "ERROR: Shared box already created (${instance_state})."
      exit 1
   fi
else
   echo 'Creating the Shared box ...'
   
   instance_id="$(run_instance \
       "${SHARED_INST_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${SHARED_INST_PRIVATE_IP}" \
       "${AWS_BASE_IMG_ID}" \
       "${TMP_DIR}"/"${shared_dir}"/cloud_init.yml)"

   echo "Shared box created."
fi  
       
eip="$(get_public_ip_address_associated_with_instance "${SHARED_INST_NM}")"

echo "Shared box public address: ${eip}."

# Verify it the SSH port is still 22 or it has changed.

ssh_port="$(get_ssh_port "${key_pair_file}" "${eip}" "${SHARED_INST_USER_NM}" '22' '38142' )"

echo "The SSH port on the Shared box is ${ssh_port}."

##
## Upload the scripts to the instance
## 

echo
echo 'Uploading the scripts to the Shared box ...'

remote_dir=/home/"${SHARED_INST_USER_NM}"/script

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${key_pair_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${SHARED_INST_USER_NM}"                     
   
## Security scripts

sed -e "s/SEDssh_portSED/${SHARED_INST_SSH_PORT}/g" \
    -e "s/AllowUsers/#AllowUsers/g" \
       "${TEMPLATE_DIR}"/common/ssh/sshd_config_template > "${TMP_DIR}"/"${shared_dir}"/sshd_config
       
echo 'sshd_config ready.'         

scp_upload_files "${key_pair_file}" "${eip}" "${ssh_port}" "${SHARED_INST_USER_NM}" "${remote_dir}" \
    "${TEMPLATE_DIR}"/common/linux/secure-linux.sh \
    "${TEMPLATE_DIR}"/common/linux/check-linux.sh \
    "${TEMPLATE_DIR}"/common/linux/yumupdate.sh \
    "${TMP_DIR}"/"${shared_dir}"/sshd_config        

echo 'Securing the Shared box ...'

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/secure-linux.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${SHARED_INST_USER_NM}" \
    "${SHARED_INST_USER_PWD}"
                 
set +e

# Harden the kernel, change SSH port to 38142, set ec2-user password and sudo with password.
ssh_run_remote_command_as_root "${remote_dir}/secure-linux.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${SHARED_INST_USER_NM}" \
    "${SHARED_INST_USER_PWD}" 
                   
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then
   echo 'Shared box successfully configured.'

   set +e
   ssh_run_remote_command_as_root "reboot" \
       "${key_pair_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${SHARED_INST_USER_NM}" \
       "${SHARED_INST_USER_PWD}"
   set -e
else
   echo 'ERROR: configuring the Shared box.'
   exit 1
fi

# Finally, remove access from SSH port 22.

granted_ssh_22="$(check_access_from_cidr_is_granted  "${sgp_id}" '22' 'tcp' '0.0.0.0/0')"

if [[ -n "${granted_ssh_22}" ]]
then 
   revoke_access_from_cidr "${sgp_id}" '22' 'tcp' '0.0.0.0/0'
   
   echo 'Revoked SSH access to the Shared box port 22.'
fi

wait_ssh_started "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${SHARED_INST_USER_NM}"

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/check-linux.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${SHARED_INST_USER_NM}" \
    "${SHARED_INST_USER_PWD}"

echo 'Running security checks in the Shared box ...'

ssh_run_remote_command_as_root "${remote_dir}/check-linux.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${SHARED_INST_USER_NM}" \
    "${SHARED_INST_USER_PWD}"  
   
# Clear remote directory.
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${SHARED_INST_USER_NM}"    
    
# After the instance is created, stop it before creating the image, to ensure data integrity. 

stop_instance "${instance_id}"   

echo 'Shared box stopped.'   

## 
## SSH Access
## 

granted_ssh_38142="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0')"

if [[ -n "${granted_ssh_38142}" ]]
then
   # Revoke SSH access from the development machine
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   
   echo 'Revoked SSH access to the Shared box.' 
   echo
fi

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"
