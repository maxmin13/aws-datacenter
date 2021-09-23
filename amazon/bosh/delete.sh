#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

BOSH_DIRECTOR_INSTALL_DIR='/opt/bosh'
bosh_dir='bosh'

echo
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

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
admin_subnet_id="${__RESULT}"

if [[ -z "${admin_subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${admin_subnet_id}."
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

get_instance_id "${ADMIN_INST_NM}"
admin_instance_id="${__RESULT}"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   admin_instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${admin_instance_id} (${admin_instance_st})."
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

if [[ -z "${admin_instance_id}" ]]
then

   echo 'Admin box not found, skipping deleting BOSH components.'

elif [[ 'running' != "${admin_instance_st}" ]]
then
   echo 'Admin box not running, skipping deleting BOSH components.'
else

   echo 'Uploading Bosh scripts to the Admin box ...'

   remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
   admin_private_key_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}"  

   wait_ssh_started "${admin_private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

   ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
       "${admin_private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"

   sed -e "s/SEDbosh_director_install_dirSED/$(escape ${BOSH_DIRECTOR_INSTALL_DIR})/g" \
       -e "s/SEDbosh_director_nmSED/${BOSH_DIRECTOR_NM}/g" \
       -e "s/SEDbosh_cidrSED/$(escape "${DTC_SUBNET_MAIN_CIDR}")/g" \
       -e "s/SEDbosh_regionSED/${DTC_DEPLOY_REGION}/g" \
       -e "s/SEDbosh_azSED/${DTC_DEPLOY_ZONE_1}/g" \
       -e "s/SEDbosh_subnet_idSED/${admin_subnet_id}/g" \
       -e "s/SEDbosh_sec_group_nmSED/${BOSH_INST_SEC_GRP_NM}/g" \
       -e "s/SEDbosh_internal_ipSED/${BOSH_INST_PRIVATE_IP}/g" \
       -e "s/SEDbosh_key_pair_nmSED/${ADMIN_INST_KEY_PAIR_NM}/g" \
       -e "s/SEDbosh_gateway_ipSED/${DTC_GATEWAY_IP}/g" \
          "${TEMPLATE_DIR}"/"${bosh_dir}"/delete_bosh_director_template.sh > "${TMP_DIR}"/"${bosh_dir}"/delete_bosh_director.sh
    
   echo 'delete_bosh_director.sh ready.'

   echo "Uploading Bosh scripts ..."

   scp_upload_files "${admin_private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TEMPLATE_DIR}"/"${bosh_dir}"/delete_bosh_components.sh \
       "${TEMPLATE_DIR}"/"${bosh_dir}"/delete_bosh_cli.sh \
       "${TMP_DIR}"/"${bosh_dir}"/delete_bosh_director.sh 
       
   echo 'Scripts uploaded.'
   echo "Removing Bosh components ..."

   # Run the install database script uploaded in the Admin server. 
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_bosh_components.sh" \
       "${admin_private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}" 
    
   set +e          
   ssh_run_remote_command_as_root "${remote_dir}/delete_bosh_components.sh" \
       "${admin_private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"   
                     
   exit_code=$?
   set -e

   # shellcheck disable=SC2181
   if [ 0 -eq "${exit_code}" ]
   then
      echo 'Bosh components successfully removed.'
   
      ssh_run_remote_command "rm -rf ${remote_dir}" \
          "${admin_private_key_file}" \
          "${admin_eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${ADMIN_INST_USER_NM}"     
   else
      echo 'ERROR: removing Bosh components.'
      exit 1
   fi
fi

## 
## Admin security group.
## 

set +e
  
revoke_access_from_security_group "${admin_sgp_id}" "0-65535" 'tcp' "${admin_sgp_id}" > /dev/null 2>&1

echo 'Revoked internal TCP traffic to Admin box'

revoke_access_from_security_group "${admin_sgp_id}" "0-65535" 'udp' "${admin_sgp_id}" > /dev/null 2>&1

echo 'Revoked internal UDP traffic to Admin box'

revoke_access_from_security_group "${admin_sgp_id}" "-1" 'icmp' "${admin_sgp_id}" > /dev/null 2>&1

echo 'Revoked internal ICMP traffic to Admin box'

set -e

## 
## Bosh security group.
## 

get_security_group_id "${BOSH_INST_SEC_GRP_NM}"
bosh_sgp_id="${__RESULT}"

if [[ -n "${bosh_sgp_id}" ]]
then
   # Create Bosh security group.
   delete_security_group "${bosh_sgp_id}" 
   
   echo 'Bosh security group deleted.'
fi

##
## Admin instance profile.
##

check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE}" > /dev/null
has_role_associated="${__RESULT}"

if [[ 'true' == "${has_role_associated}" ]]
then
   ####
   #### Sessions may still be actives, they should be terminated by adding AWSRevokeOlderSessions permission
   #### to the role.
   ####
   remove_role_from_instance_profile "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE}"
  
   echo 'Bosh director role removed from the instance profile.'
else
   echo 'WARN: Bosh director role already removed from the instance profile.'
fi
      
## 
## Admin SSH Access.
## 

# Revoke SSH access from the development machine
set +e
revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Admin box.' 

## Clearing.
rm -rf "${TMP_DIR:?}"/"${bosh_dir}"




