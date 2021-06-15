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
   echo '* ERROR: Data Center not found.'
   exit 1
else
   echo "* Data Center ID: ${dtc_id}."
fi

subnet_id="$(get_subnet_id "${DTC_SUBNET_MAIN_NM}")"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main Subnet not found.'
   exit 1
else
   echo "* main Subnet ID: ${subnet_id}."
fi

image_id="$(get_image_id "${SHAR_IMAGE_NM}")"
image_state="$(get_image_state "${SHAR_IMAGE_NM}")"

if [[ -n "${image_id}" ]]
then
   if [[ 'available' == "${image_state}" ]]
   then
      # If the image is alredy available, no need to run the script.
      echo "* WARN: the image is already created (${image_state}), skipping creating the Shared box." 
      echo
      
      return
   else
      echo "* ERROR: the image is already created (${image_state})."
      
      exit 1 
   fi
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"
mkdir "${TMP_DIR}"/"${shared_dir}"

## 
## Security Group
##

sgp_id="$(get_security_group_id "${SHAR_INSTANCE_SEC_GRP_NM}")"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Shared Security Group is already created.'
else
   sgp_id="$(create_security_group "${dtc_id}" "${SHAR_INSTANCE_SEC_GRP_NM}" 'Shared Security Group')"  

   echo 'Created Shared Security Group.'
fi

granted_ssh_22="$(check_access_from_cidr_is_granted  "${sgp_id}" '22' '0.0.0.0/0')"

if [[ -z "${granted_ssh_22}" ]]
then
   allow_access_from_cidr "${sgp_id}" '22' '0.0.0.0/0'
   
   echo 'Granted SSH access on port 22.'
fi

granted_ssh_38142="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -z "${granted_ssh_38142}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo "Granted SSH access on port ${SHAR_INSTANCE_SSH_PORT}."
fi

##
## Cloud init
##   

## Removes the default user, creates the admin-user user and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${SHAR_INSTANCE_USER_PWD}")" 

key_pair_file="$(get_keypair_file_path "${SHAR_INSTANCE_KEY_PAIR_NM}" "${SHAR_INSTANCE_ACCESS_DIR}")"

if [[ -f "${key_pair_file}" ]]
then
   echo 'WARN: SSH key-pair already created.'
else
   # Save the private key file in the access directory
   mkdir -p "${SHAR_INSTANCE_ACCESS_DIR}"
   generate_keypair "${key_pair_file}" "${SRV_ADMIN_EMAIL}" 
      
   echo 'SSH key-pair created.'
fi

public_key="$(get_public_key "${key_pair_file}")"
 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${SHAR_INSTANCE_USER_NM}" -v hostname="${SHAR_INSTANCE_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${TEMPLATE_DIR}"/common/cloud-init/cloud_init_template.yml > "${TMP_DIR}"/"${shared_dir}"/cloud_init.yml
  
echo 'cloud_init.yml ready.'  

## 
## Shared box
## 

instance_state="$(get_instance_state "${SHAR_INSTANCE_NM}")"

if [[ -n "${instance_state}" && 'running' == "${instance_state}" ]]
then
   instance_id="$(get_instance_id "${SHAR_INSTANCE_NM}")"

   echo "WARN: Shared box already created (${instance_state})."
   
elif [[ -n "${instance_state}" && 'running' != "${instance_state}" ]]
then
   echo "ERROR: Shared box already created (${instance_state})."
   
   exit
else
   echo 'Creating the Shared box ...'
   
   instance_id="$(run_instance \
       "${SHAR_INSTANCE_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${SHAR_INSTANCE_PRIVATE_IP}" \
       "${AWS_BASE_AMI_ID}" \
       "${TMP_DIR}"/"${shared_dir}"/cloud_init.yml)"

   echo "Shared box created."
fi  
       
eip="$(get_public_ip_address_associated_with_instance "${SHAR_INSTANCE_NM}")"

echo "Shared box public address: ${eip}."

# Verify it the SSH port is still 22 or it has changed.

ssh_port="$(get_ssh_port "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_USER_NM}" '22' '38142' )"

echo "The SSH port on the Shared box is ${ssh_port}."

##
## Upload the scripts to the instance
## 

echo
echo 'Uploading the scripts to the Shared box ...'

remote_dir=/home/"${SHAR_INSTANCE_USER_NM}"/script

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${key_pair_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${SHAR_INSTANCE_USER_NM}"                     
   
## Security scripts

sed -e "s/SEDssh_portSED/${SHAR_INSTANCE_SSH_PORT}/g" \
    -e "s/AllowUsers/#AllowUsers/g" \
       "${TEMPLATE_DIR}"/common/ssh/sshd_config_template > "${TMP_DIR}"/"${shared_dir}"/sshd_config
       
echo 'sshd_config ready.'         

scp_upload_files "${key_pair_file}" "${eip}" "${ssh_port}" "${SHAR_INSTANCE_USER_NM}" "${remote_dir}" \
    "${TEMPLATE_DIR}"/common/linux/secure-linux.sh \
    "${TEMPLATE_DIR}"/common/linux/check-linux.sh \
    "${TEMPLATE_DIR}"/common/linux/yumupdate.sh \
    "${TMP_DIR}"/"${shared_dir}"/sshd_config        

echo 'Securing the Shared box ...'

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/secure-linux.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${SHAR_INSTANCE_USER_NM}" \
    "${SHAR_INSTANCE_USER_PWD}"
                 
set +e

# Harden the kernel, change SSH port to 38142, set ec2-user password and sudo with password.
ssh_run_remote_command_as_root "${remote_dir}/secure-linux.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${SHAR_INSTANCE_USER_NM}" \
    "${SHAR_INSTANCE_USER_PWD}" 
                   
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
       "${SHAR_INSTANCE_USER_NM}" \
       "${SHAR_INSTANCE_USER_PWD}"
   set -e
else
   echo 'ERROR: configuring the Shared box.'
   exit 1
fi

# Finally, remove access from SSH port 22.

granted_ssh_22="$(check_access_from_cidr_is_granted  "${sgp_id}" '22' '0.0.0.0/0')"

if [[ -n "${granted_ssh_22}" ]]
then 
   revoke_access_from_cidr "${sgp_id}" '22' '0.0.0.0/0'
   
   echo 'Revoked SSH access to the Shared box port 22.'
fi

wait_ssh_started "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SHAR_INSTANCE_USER_NM}"

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/check-linux.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SHAR_INSTANCE_USER_NM}" \
    "${SHAR_INSTANCE_USER_PWD}"

echo 'Running security checks in the Shared box ...'

ssh_run_remote_command_as_root "${remote_dir}/check-linux.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SHAR_INSTANCE_USER_NM}" \
    "${SHAR_INSTANCE_USER_PWD}"  
   
# Clear remote directory.
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SHAR_INSTANCE_USER_NM}"    
    
# After the instance is created, stop it before creating the image, to ensure data integrity. 

stop_instance "${instance_id}"   

echo 'Shared box stopped.'   

## 
## SSH Access
## 

granted_ssh_38142="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_ssh_38142}" ]]
then
   # Revoke SSH access from the development machine
   revoke_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo 'Revoked SSH access to the Shared box.' 
fi

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"

echo
echo "Shared box created."
echo
