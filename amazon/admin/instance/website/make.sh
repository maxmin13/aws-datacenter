#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# # Deploy the Admin website.
###############################################

APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='admin.http.virtualhost.maxmin.it.conf' 
WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE='admin.https.virtualhost.maxmin.it.conf'
WEBSITE_DOCROOT_ID='admin.maxmin.it'
WEBSITE_ARCHIVE='admin.zip'
admin_dir='admin'

echo
echo '*************'
echo 'Admin website'
echo '*************'
echo

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Admin box not found.'
   exit 1
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   exit 1
else
   echo "* Admin public IP address: ${eip}."
fi

echo

# Clear old files
rm -rf "${TMP_DIR:?}"/"${admin_dir}"
mkdir "${TMP_DIR}"/"${admin_dir}"

## 
## SSH Access
## 

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access to the Admin box.'

##
## Upload scripts
## 

echo 'Uploading the scripts to the Admin box ...'

remote_dir=/home/"${ADMIN_INST_USER_NM}"/script

private_key_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}"   

sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDwebsite_archiveSED/${WEBSITE_ARCHIVE}/g" \
    -e "s/SEDwebsite_http_virtualhost_fileSED/${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_https_virtualhost_fileSED/${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_http_portSED/${ADMIN_APACHE_WEBSITE_HTTP_PORT}/g" \
    -e "s/SEDwebsite_https_portSED/${ADMIN_APACHE_WEBSITE_HTTPS_PORT}/g" \
    -e "s/SEDwebsite_docroot_idSED/${WEBSITE_DOCROOT_ID}/g" \
       "${TEMPLATE_DIR}"/admin/website/install_admin_website_template.sh > "${TMP_DIR}"/"${admin_dir}"/install_admin_website.sh  

echo 'install_admin_website.sh ready.'

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/install_admin_website.sh 

## Website source files

cd "${TMP_DIR}"/"${admin_dir}" || exit
cp -R "${ADMIN_INST_SRC_DIR}"/* ./

# Tell the admin website it's running on AWS and
# insert the email to send from
sed -i -e "s/SEDis_devSED/0/g" \
    -e "s/SEDsend_email_fromSED/${ADMIN_INST_EMAIL}/g" \
       init.php 

zip -r "${WEBSITE_ARCHIVE}" ./*.php ./*.css > /dev/null 2>&1
echo "${WEBSITE_ARCHIVE} ready."

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_ARCHIVE}"  

# Website HTTP virtualhost file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${ADMIN_APACHE_WEBSITE_HTTP_PORT}" \
    "${ADMIN_INST_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${WEBSITE_DOCROOT_ID}"        
     
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'admin' \
    "${APACHE_DOCROOT_DIR}" \
    "${WEBSITE_DOCROOT_ID}" \
    'index.php' 
                      
echo "${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE} ready."  

# Website HTTPS virtualhost file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${ADMIN_APACHE_WEBSITE_HTTPS_PORT}" \
    "${ADMIN_INST_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${WEBSITE_DOCROOT_ID}"        
     
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    'admin' \
    "${APACHE_DOCROOT_DIR}" \
    "${WEBSITE_DOCROOT_ID}" \
    'index.php' 
                      
echo "${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE} ready." 
                             
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}"

echo "Installing Admin website ..."

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_admin_website.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}"

set +e     
           
ssh_run_remote_command_as_root "${remote_dir}/install_admin_website.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}"      
exit_code=$?	
set -e

# shellcheck disable=SC2181
if [ 0 -eq "${exit_code}" ]
then 
   echo 'Admin website installed.'  
     
   ssh_run_remote_command "rm -rf ${remote_dir:?}" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"   
                   
   echo 'Cleared remote directory.'
else
   echo 'ERROR: installing Admin website.'
   exit 1
fi
            
## 
## SSH Access.
## 

# Revoke SSH access from the development machine
set +e
revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Admin box.'
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${admin_dir}"  

echo
echo "Admin website up and running at: ${eip}." 

