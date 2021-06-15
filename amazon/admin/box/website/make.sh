#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Deploy the Admin website on port 80

APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='admin.http.virtualhost.maxmin.it.conf' 
WEBSITE_DOCROOT_ID='admin.maxmin.it'
WEBSITE_ARCHIVE='admin.zip'

admin_dir='admin'

echo '*************'
echo 'Admin website'
echo '*************'
echo

instance_id="$(get_instance_id "${SRV_ADMIN_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Admin instance not found.'
   exit 1
else
   echo "* Admin instance ID: ${instance_id}."
fi

sgp_id="$(get_security_group_id "${SRV_ADMIN_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: Admin Security Group not found.'
   exit 1
else
   echo "* Admin Security Group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${SRV_ADMIN_NM}")"

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

granted_ssh="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_ssh}" ]]
then
   echo 'WARN: SSH access to the Admin box already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo 'Granted SSH access to the Admin box.'
fi

##
## Upload scripts
## 

echo 'Uploading the scripts to the Admin box ...'

remote_dir=/home/"${SRV_ADMIN_USER_NM}"/script

key_pair_file="$(get_keypair_file_path "${SRV_ADMIN_KEY_PAIR_NM}" "${SRV_ADMIN_ACCESS_DIR}")"
wait_ssh_started "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}"   

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDwebsite_archiveSED/${WEBSITE_ARCHIVE}/g" \
    -e "s/SEDwebsite_http_virtualhost_fileSED/${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_http_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTP_PORT}/g" \
    -e "s/SEDwebsite_docroot_idSED/${WEBSITE_DOCROOT_ID}/g" \
       "${TEMPLATE_DIR}"/admin/website/install_admin_website_template.sh > "${TMP_DIR}"/"${admin_dir}"/install_admin_website.sh  

echo 'install_admin_website.sh ready.'

scp_upload_file "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/install_admin_website.sh 

## Website source files

cd "${TMP_DIR}"/"${admin_dir}" || exit
cp -R "${SRV_ADMIN_SRC_DIR}"/* ./

# Tell the admin website it's running on AWS and
# insert the email to send from
sed -i -e "s/SEDis_devSED/0/g" \
    -e "s/SEDsend_email_fromSED/${SRV_ADMIN_EMAIL}/g" \
       init.php 

zip -r "${WEBSITE_ARCHIVE}" ./*.php ./*.css > /dev/null 2>&1
echo "${WEBSITE_ARCHIVE} ready."

scp_upload_file "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_ARCHIVE}"  

# Website virtualhost file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${SRV_ADMIN_APACHE_WEBSITE_HTTP_PORT}" \
    "${SRV_ADMIN_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${WEBSITE_DOCROOT_ID}"        
     
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'admin' \
    "${APACHE_DOCROOT_DIR}" \
    "${WEBSITE_DOCROOT_ID}" \
    'index.php' 
                      
echo "${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE} ready."  
                             
scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" 

echo "Installing Admin website ..."

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_admin_website.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}" \
    "${SRV_ADMIN_USER_PWD}"

set +e     
           
ssh_run_remote_command_as_root "${remote_dir}/install_admin_website.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}" \
    "${SRV_ADMIN_USER_PWD}" 
      
exit_code=$?	
set -e

# shellcheck disable=SC2181
if [ 0 -eq "${exit_code}" ]
then 
   echo 'Admin website installed.'  
     
   ssh_run_remote_command "rm -rf ${remote_dir:?}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}"   
                   
   echo 'Cleared remote directory.'
else
   echo 'ERROR: installing Admin website.'
   
   exit 1
fi
            
## 
## SSH Access.
## 

granted_ssh="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_ssh}" ]]
then
   # Revoke SSH access from the development machine
   revoke_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo 'Revoked SSH access to the Admin box.' 
fi
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${admin_dir}"  

echo
echo "Admin website up and running at: ${eip}." 
echo
