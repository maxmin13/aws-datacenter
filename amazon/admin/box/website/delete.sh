#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# # Removes the Admin website.
###############################################

APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='admin.http.virtualhost.maxmin.it.conf'  
WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE='admin.https.virtualhost.maxmin.it.conf'  
WEBSITE_DOCROOT_ID='admin.maxmin.it'
admin_dir='admin'

echo '*************'
echo 'Admin website'
echo '*************'
echo

instance_id="$(get_instance_id "${SRV_ADMIN_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   instance_st="$(get_instance_state "${SRV_ADMIN_NM}")"
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

sgp_id="$(get_security_group_id "${SRV_ADMIN_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Admin security group not found.'
else
   echo "* Admin security group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${SRV_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Admin public IP address not found.'
else
   echo "* Admin public IP address: ${eip}."
fi

echo

# Clearing local files
rm -rf "${TMP_DIR:?}"/"${admin_dir}"
mkdir "${TMP_DIR}"/"${admin_dir}"

if [[ -n "${instance_id}" && 'running' == "${instance_st}" ]]
then

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
       -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
       -e "s/SEDwebsite_docroot_idSED/${WEBSITE_DOCROOT_ID}/g" \
       -e "s/SEDwebsite_http_virtualhost_fileSED/${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDwebsite_https_virtualhost_fileSED/${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDwebsite_http_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTP_PORT}/g" \
       -e "s/SEDwebsite_https_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTPS_PORT}/g" \
          "${TEMPLATE_DIR}"/admin/website/delete_admin_website_template.sh > "${TMP_DIR}"/"${admin_dir}"/delete_admin_website.sh
          
   echo 'delete_admin_website.sh ready' 
                                    
   scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
      "${TMP_DIR}"/admin/delete_admin_website.sh 
    
   echo 'Deleting Admin website ...'

   # Delete the Admin website
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_admin_website.sh" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}" \
       "${SRV_ADMIN_USER_PWD}" 
        
   set +e     
           
   ssh_run_remote_command_as_root "${remote_dir}/delete_admin_website.sh" \
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
      echo 'Admin website sucessfully removed.'
      
      ssh_run_remote_command "rm -rf ${remote_dir:?}" \
          "${key_pair_file}" \
          "${eip}" \
          "${SHAR_INSTANCE_SSH_PORT}" \
          "${SRV_ADMIN_USER_NM}"   
                   
      echo 'Cleared remote directory.'
   else
      echo 'ERROR: removing Admin website.'  
      exit 1
   fi                 

   ## 
   ## SSH Access.
   ## 
   
   if [[ -n "${granted_ssh}" ]]
   then
      # Revoke SSH access from the development machine
      revoke_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
      echo 'Revoked SSH access to the Admin box.' 
   fi
    
   # Removing temp files
   rm -rf "${TMP_DIR:?}"/"${admin_dir}"  

   echo
   echo "Admin website removed."
   echo
fi

