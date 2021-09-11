#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##############################################################
# Uploads the scripts to the Admin server and install:
# Bosh cli
# Bosh director
##############################################################

bosh_dir='bosh'

echo '***************'
echo 'Bosh components'
echo '***************'
echo

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_instance_id "${ADMIN_INST_NM}"
admin_instance_id="${__RESULT}"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${admin_instance_id} (${instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
admin_sgp_id="${__RESULT}"

if [[ -z "${admin_sgp_id}" ]]
then
   echo '* ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${admin_sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
admin_eip="${__RESULT}"

if [[ -z "${admin_eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   exit 1
else
   echo "* Admin public IP address: ${admin_eip}."
fi

echo

# Clear old files
rm -rf "${TMP_DIR:?}"/"${bosh_dir}"
mkdir "${TMP_DIR}"/"${bosh_dir}"

##
## Instance profile.
##

## Check the Admin instance profile has the Bosh director role associated.
## The role is needed to install Bosh director VM.
check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE}" > /dev/null
has_role_associated="${__RESULT}"

if [[ 'false' == "${has_role_associated}" ]]
then
   # IAM is a bit slow, it might be necessary to wait a bit. 
   associate_role_to_instance_profile "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE}"
  
   echo 'Bosh director role associated to the instance profile.'
else
   echo 'WARN: Bosh director role already associated to the instance profile.'
fi

## 
## Security group.
## 

get_security_group_id "${BOSH_SEC_GRP_NM}"
bosh_sgp_id="${__RESULT}"

if [[ -z "${bosh_sgp_id}" ]]
then
   # Create Bosh security group.
   create_security_group "${dtc_id}" "${BOSH_SEC_GRP_NM}" 'BOSH deployed VMs.'
   get_security_group_id "${BOSH_SEC_GRP_NM}"
   bosh_sgp_id="${__RESULT}"
   
   echo 'Created Bosh security group.'.
else
   echo 'WARN: Bosh security group is already created.'
fi

set +e
#allow_access_from_cidr "${sgp_id}" "${BOSH_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
#echo 'Granted SSH access to Bosh CLI.'

#allow_access_from_cidr "${sgp_id}" "${BOSH_AGENT_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
#echo 'Granted access to Bosh agent for bootstrapping.'

set -e

## 
## SSH Access 
## 

set +e
allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access to the Admin box.'

echo 'Uploading Bosh scripts to the Admin box ...'

remote_dir=/home/"${ADMIN_INST_USER_NM}"/script

key_pair_file="$(get_local_keypair_file_path "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}")"
wait_ssh_started "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${key_pair_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}"  

sed "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    "${TEMPLATE_DIR}"/"${bosh_dir}"/install_bosh_components_template.sh > "${TMP_DIR}"/"${bosh_dir}"/install_bosh_components.sh
    
echo 'install_bosh_components.sh ready.'    
    
sed "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    "${TEMPLATE_DIR}"/"${bosh_dir}"/install_bosh_cli_template.sh > "${TMP_DIR}"/"${bosh_dir}"/install_bosh_cli.sh
    
echo 'install_bosh_cli.sh ready.'

sed "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    "${TEMPLATE_DIR}"/"${bosh_dir}"/install_bosh_director_template.sh > "${TMP_DIR}"/"${bosh_dir}"/install_bosh_director.sh
    
echo 'install_bosh_director.sh ready.'

echo "Uploading Bosh scripts ..."  
  
scp_upload_files "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${bosh_dir}"/install_bosh_components.sh \
    "${TMP_DIR}"/"${bosh_dir}"/install_bosh_cli.sh \
    "${TMP_DIR}"/"${bosh_dir}"/install_bosh_director.sh
       
echo 'Scripts uploaded.'
echo "Installing Bosh components ..."
 
# Run the install database script uploaded in the Admin server. 
ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_bosh_components.sh" \
    "${key_pair_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}" 
    
set +e   
          
ssh_run_remote_command_as_root "${remote_dir}/install_bosh_components.sh" \
    "${key_pair_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}"   
                     
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 0 -eq "${exit_code}" ]
then
   echo 'Bosh components successfully installed.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
       "${key_pair_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"     
else
   echo 'ERROR: installing Bosh components.'
   exit 1
fi
      
## 
## SSH Access.
## 

# Revoke SSH access from the development machine
set +e
###revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Admin box.' 
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${bosh_dir}" 
 
echo
echo "Bosh components installed." 
echo

