#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####################################################################
# Uploads the scripts to the Admin server and install the Devops 
# components:
#  BOSH client
#  Terraform client
#  BOSH bootloader client
#  BOSH director
#  Cloud Foundry.
####################################################################

BBL_INSTALL_DIR='/opt/bbl'
CF_INSTALL_DIR='/opt/cf'
CF_LBAL_DOMAIN='cflbal'."${MAXMIN_TLD}"

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
mkdir -p "${TMP_DIR}"/"${devops_dir}"

## 
## Admin security group.
## 

set +e

# Access to Admin from local machine.
allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
echo 'Granted SSH access to Admin instance.'

set -e

#
# Instance profile.
#
   
## Check the Admin instance profile has the BOSH director role associated.
check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE_NM}" > /dev/null
has_role_associated="${__RESULT}"

if [[ 'false' == "${has_role_associated}" ]]
then
   # IAM is a bit slow, it might be necessary to retry the certificate request a few times. 
   associate_role_to_instance_profile "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE_NM}"
      
   echo 'BOSH director role associated to the instance profile.'
else
   echo 'WARN: BOSH director role already associated to the instance profile.'
fi   

echo 'Preparing devops scripts for the Admin box ...'

remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
admin_private_key_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}"  

wait_ssh_started "${admin_private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${admin_private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}"  

sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
       "${TEMPLATE_DIR}"/devops/install_devops_components_template.sh > "${TMP_DIR}"/"${devops_dir}"/install_devops_components.sh
    
echo 'install_devops_components.sh ready.' 

sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    -e "s/SEDbosh_cli_download_urlSED/$(escape "${BOSH_CLI_DOWNLOAD_URL}")/g" \
       "${TEMPLATE_DIR}"/devops/bosh/install_bosh_cli_template.sh > "${TMP_DIR}"/"${devops_dir}"/install_bosh_cli.sh
    
echo 'install_bosh_cli.sh ready.'

sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    -e "s/SEDbbl_download_urlSED/$(escape "${BOSH_BBL_CLI_DOWNLOAD_URL}")/g" \
       "${TEMPLATE_DIR}"/devops/bbl/install_bbl_cli_template.sh > "${TMP_DIR}"/"${devops_dir}"/install_bbl_cli.sh
    
echo 'install_bbl_cli.sh ready.'

sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    -e "s/SEDterraform_download_urlSED/$(escape "${TERRAFORM_CLI_DOWNLOAD_URL}")/g" \
       "${TEMPLATE_DIR}"/devops/terraform/install_terraform_cli_template.sh > "${TMP_DIR}"/"${devops_dir}"/install_terraform_cli.sh
    
echo 'install_terraform_cli.sh ready.'

# director_vars.yml used to deploy BISH director.
{
   echo iam_instance_profile: "${ADMIN_INST_PROFILE_NM}"

} > "${TMP_DIR}"/"${devops_dir}"/director_vars.yml

echo 'cf_vars.yml ready.'

## BBL does not accept AWS session token for authentication (AWS STS temporary credentials)
access_key_id="$(aws configure get aws_access_key_id)"
secret_access_key="$(aws configure get aws_secret_access_key)"

sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    -e "s/SEDaccess_key_idSED/${access_key_id}/g" \
    -e "s/SEDsecret_access_keySED/$(escape "${secret_access_key}")/g" \
    -e "s/SEDregionSED/${DTC_REGION}/g" \
    -e "s/SEDbbl_install_dirSED/$(escape "${BBL_INSTALL_DIR}")/g" \
    -e "s/SEDcf_lbal_domainSED/${CF_LBAL_DOMAIN}/g" \
       "${TEMPLATE_DIR}"/devops/boshdirector/install_boshdirector_with_bbl_template.sh > "${TMP_DIR}"/"${devops_dir}"/install_boshdirector_with_bbl.sh
    
echo 'install_boshdirector_with_bbl.sh ready.'

sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    -e "s/SEDcf_download_urlSED/$(escape "${CF_DOWNLOAD_URL}")/g" \
    -e "s/SEDcf_install_dirSED/$(escape "${CF_INSTALL_DIR}")/g" \
    -e "s/SEDcf_lbal_domainSED/${CF_LBAL_DOMAIN}/g" \
    -e "s/SEDbbl_install_dirSED/$(escape "${BBL_INSTALL_DIR}")/g" \
    -e "s/SEDubuntu_bionic_stemcell_urlSED/$(escape "${UBUNTU_BIONIC_STEMCELL_URL}")/g" \
       "${TEMPLATE_DIR}"/devops/cloudfoundry/install_cloudfoundry_template.sh > "${TMP_DIR}"/"${devops_dir}"/install_cloudfoundry.sh
    
echo 'install_cloudfoundry.sh ready.'

############ TODO for production a valid CA certificate shoud be used.
      
# Create a self-signed Certificate.
sed -e "s/SEDcountrySED/${DEV_CF_CRT_COUNTRY_NM}/g" \
    -e "s/SEDstate_or_provinceSED/${DEV_CF_CRT_PROVINCE_NM}/g" \
    -e "s/SEDcitySED/${DEV_CF_CRT_CITY_NM}/g" \
    -e "s/SEDorganizationSED/${DEV_CF_CRT_ORGANIZATION_NM}/g" \
    -e "s/SEDunit_nameSED/${DEV_CF_CRT_UNIT_NM}/g" \
    -e "s/SEDcommon_nameSED/${CF_LBAL_DOMAIN}/g" \
    -e "s/SEDemail_addressSED/${ADMIN_INST_EMAIL}/g" \
       "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_certificate_template.sh > "${TMP_DIR}"/"${devops_dir}"/gen_certificate.sh
       
echo 'gen_certificate.sh ready.'

# cf_vars.yml used to deploy CF.
{
   echo sc_version: "${UBUNTU_BIONIC_STEMCELL_URL##*=}"

} > "${TMP_DIR}"/"${devops_dir}"/cf_vars.yml

echo 'cf_vars.yml ready.'
echo "Uploading devops scripts ..."

scp_upload_files "${admin_private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${devops_dir}"/install_devops_components.sh \
    "${TMP_DIR}"/"${devops_dir}"/install_bosh_cli.sh \
    "${TMP_DIR}"/"${devops_dir}"/install_terraform_cli.sh \
    "${TMP_DIR}"/"${devops_dir}"/install_bbl_cli.sh \
    "${TMP_DIR}"/"${devops_dir}"/install_boshdirector_with_bbl.sh \
    "${TEMPLATE_DIR}"/devops/boshdirector/config/enable_debug.yml \
    "${TEMPLATE_DIR}"/devops/boshdirector/config/disable_debug.yml \
    "${TEMPLATE_DIR}"/devops/boshdirector/config/create-director-override.sh \
    "${TMP_DIR}"/"${devops_dir}"/director_vars.yml \
    "${TMP_DIR}"/"${devops_dir}"/install_cloudfoundry.sh \
    "${TEMPLATE_DIR}"/devops/cloudfoundry/config/cf_use_bionic_stemcell.yml \
    "${TMP_DIR}"/"${devops_dir}"/cf_vars.yml \
    "${TEMPLATE_DIR}"/devops/functions/bosh_functions.sh \
    "${TEMPLATE_DIR}"/devops/functions/bbl_functions.sh \
    "${TEMPLATE_DIR}"/devops/functions/utils.sh \
    "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_rsa.sh \
    "${TEMPLATE_DIR}"/common/ssl/selfsigned/remove_passphase.sh \
    "${TMP_DIR}"/"${devops_dir}"/gen_certificate.sh \
    "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_selfsigned_certificate.sh
       
echo 'Scripts uploaded.'
echo "Installing devops components ..."
 
# Run the install database script uploaded in the Admin server. 
ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_devops_components.sh" \
    "${admin_private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}" 
    
set +e          
ssh_run_remote_command_as_root "${remote_dir}/install_devops_components.sh" \
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
   echo 'Devops components successfully installed.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
      "${admin_private_key_file}" \
      "${admin_eip}" \
      "${SHARED_INST_SSH_PORT}" \
      "${ADMIN_INST_USER_NM}"     
else
   echo 'ERROR: installing devops components.'
   exit 1
fi

#
# Instance profile.
#

check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE_NM}" > /dev/null
has_role_associated="${__RESULT}"

if [[ 'true' == "${has_role_associated}" ]]
then
   ####
   #### Sessions may still be actives, they should be terminated by adding AWSRevokeOlderSessions permission
   #### to the role.
   ####
   remove_role_from_instance_profile "${ADMIN_INST_PROFILE_NM}" "${AWS_BOSH_DIRECTOR_ROLE_NM}"
     
   echo 'BOSH director role removed from the instance profile.'
else
   echo 'WARN: BOSH director role already removed from the instance profile.'
fi
      
## 
## Admin SSH Access.
## 

# Revoke SSH access from the development machine
set +e
revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Admin box.'
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${devops_dir}" 
 
echo
echo 'Devops components installed.' 


