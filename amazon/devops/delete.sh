#!/bin/bash
   
set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

####################################################################
# Uploads the scripts to the Admin server and delete the Devops 
# components:
#  BOSH client
#  Terraform client
#  BOSH bootloader client
#  BOSH director
#  Cloud Foundry.
####################################################################

BBL_INSTALL_DIR='/opt/bbl'
CF_INSTALL_DIR='/opt/cf'
devops_dir='devops'

echo
echo '*****************'
echo 'Devops components'
echo '*****************'
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
rm -rf "${TMP_DIR:?}"/"${devops_dir}"
mkdir "${TMP_DIR}"/"${devops_dir}"

if [[ -z "${admin_instance_id}" ]]
then
   echo 'Admin box not found, skipping deleting BOSH components.'
   
elif [[ 'running' != "${admin_instance_st}" ]]
then
   echo 'Admin box not running, skipping deleting BOSH components.'
else
   echo 'Preparing devops scripts for the Admin box ...'

   remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
   admin_private_key_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}"  

   wait_ssh_started "${admin_private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

   ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
       "${admin_private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"
     
   ## TODO can BBL work with temp credentials or profiles ?????
   access_key_id="$(aws configure get aws_access_key_id)"
   secret_access_key="$(aws configure get aws_secret_access_key)"

   sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
       -e "s/SEDaccess_key_idSED/${access_key_id}/g" \
       -e "s/SEDsecret_access_keySED/$(escape "${secret_access_key}")/g" \
       -e "s/SEDregionSED/${DTC_REGION}/g" \
       -e "s/SEDbbl_install_dirSED/$(escape "${BBL_INSTALL_DIR}")/g" \
       -e "s/SEDlbal_subdomainSED/system/g" \
       -e "s/SEDlbal_domainSED/${MAXMIN_TLD}/g" \
          "${TEMPLATE_DIR}"/devops/boshdirector/delete_boshdirector_with_bbl_template.sh > "${TMP_DIR}"/"${devops_dir}"/delete_boshdirector_with_bbl.sh
    
   echo 'delete_boshdirector_with_bbl.sh ready.'    
   
   sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
       -e "s/SEDcf_install_dirSED/$(escape "${CF_INSTALL_DIR}")/g" \
       -e "s/SEDbbl_install_dirSED/$(escape "${BBL_INSTALL_DIR}")/g" \
          "${TEMPLATE_DIR}"/devops/cloudfoundry/delete_cloudfoundry_template.sh > "${TMP_DIR}"/"${devops_dir}"/delete_cloudfoundry.sh
    
   echo 'install_cloudfoundry.sh ready.'  
   echo "Uploading devops scripts ..."

   scp_upload_files "${admin_private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TEMPLATE_DIR}"/devops/delete_devops_components.sh \
       "${TEMPLATE_DIR}"/devops/bosh/delete_bosh_cli.sh \
       "${TEMPLATE_DIR}"/devops/bbl/delete_bbl_cli.sh \
       "${TEMPLATE_DIR}"/devops/terraform/delete_terraform_cli.sh \
       "${TMP_DIR}"/"${devops_dir}"/delete_cloudfoundry.sh \
       "${TMP_DIR}"/"${devops_dir}"/delete_boshdirector_with_bbl.sh \
       "${TEMPLATE_DIR}"/devops/functions/bosh_functions.sh \
       "${TEMPLATE_DIR}"/devops/functions/bbl_functions.sh  
       
   echo 'Scripts uploaded.'
   echo "Removing devops components ..."

   # Run the install database script uploaded in the Admin server. 
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_devops_components.sh" \
       "${admin_private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}" 
    
   set +e          
   ssh_run_remote_command_as_root "${remote_dir}/delete_devops_components.sh" \
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
      echo 'Devops components successfully removed.'
    
      ssh_run_remote_command "rm -rf ${remote_dir}" \
          "${admin_private_key_file}" \
          "${admin_eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${ADMIN_INST_USER_NM}"     
   else
      echo 'ERROR: removing devops components.'
      exit 1
   fi
fi
     
## 
## Admin SSH Access.
## 

if [[ -n "${admin_sgp_id}" ]]
then
   # Revoke SSH access from the development machine
   set +e
   revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Revoked SSH access to the Admin box.' 
fi

## Clearing.
rm -rf "${TMP_DIR:?}"/"${devops_dir}"

