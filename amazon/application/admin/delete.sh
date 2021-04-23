#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_DOC_ROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
PUBLIC_VIRTUALHOST_CONFIG_FILE='public.virtualhost.maxmin.it.conf' 

echo '*************'
echo 'Admin website'
echo '*************'
echo

admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_instance_id}" ]]
then
   echo "Instance '${SERVER_ADMIN_NM}' not found"
else
   echo "* Admin instance ID: '${admin_instance_id}'"
fi

admin_sgp_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -z "${admin_sgp_id}" ]]
then
   echo 'The Admin security group not found'
else
   echo "* Admin Security Group ID: '${admin_sgp_id}'"
fi

admin_eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_eip}" ]]
then
   echo 'Admin public IP address not found'
else
   echo "* Admin public IP address: '${admin_eip}'"
fi

echo
echo 'Deleting Admin website ...'

# Clearing local files
rm -rf "${TMP_DIR}"/admin
mkdir "${TMP_DIR}"/admin

if [[ -n "${admin_eip}" && -n "${admin_instance_id}" && -n "${admin_sgp_id}" ]]
then
   ## *** ##
   ## SSH ##
   ## *** ##
   
   ## Get the Key Pair to SSH the box
   key_pair_id="$(get_key_pair_id "${SERVER_ADMIN_KEY_PAIR_NM}")"
  
   # Check if the Admin Security Group grants access from the development machine through SSH port
   my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
   access_granted="$(check_access_from_cidr_is_granted "${admin_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
   
   if [[ -z "${access_granted}" ]]
   then
      allow_access_from_cidr "${admin_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
      echo "Granted SSH access to development machine" 
   else
      echo 'SSH access already granted to development machine'    
   fi
   
   echo 'Waiting for SSH to start'
   private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_CREDENTIALS_DIR}")" 
   wait_ssh_started "${private_key}" "${admin_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"   
   
   ## ******* ##
   ## Modules ##
   ## ******* ##

   sed -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
       -e "s/SEDapache_doc_root_dirSED/$(escape ${APACHE_DOC_ROOT_DIR})/g" \
       -e "s/SEDadmin_domain_nameSED/${SERVER_ADMIN_HOSTNAME}/g" \
          "${TEMPLATE_DIR}"/admin/delete_admin_website_template.sh > "${TMP_DIR}"/admin/delete_admin_website.sh     
   
   # Download the virtualhost file from the server.
   scp_download_file "${private_key}" \
                     "${admin_eip}" \
                     "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                     "${DEFAUT_AWS_USER}" \
                     "${APACHE_SITES_AVAILABLE_DIR}"/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" \
                     "${TMP_DIR}"/admin   

   echo 'Virtualhost configuration file downloaded'

   # Disable the Admin website.                                     
   remove_alias_from_virtual_host 'admin' \
                                    "${APACHE_DOC_ROOT_DIR}" \
                                    "${SERVER_ADMIN_HOSTNAME}" \
                                    "${TMP_DIR}"/admin/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" 
                                    
   echo 'Removed Admin web site from the enabled virtualhosts'                                 
   
   scp_upload_files "${private_key}" "${admin_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
                   "${TMP_DIR}"/admin/websiste/delete_admin_website.sh \
                   "${TMP_DIR}"/admin/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" 

   # Delete the Admin website
   ssh_run_remote_command 'chmod +x delete_admin_website.sh' \
                   "${private_key}" \
                   "${admin_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}" 
             
   set +e              
   ssh_run_remote_command './delete_admin_website.sh' \
                   "${private_key}" \
                   "${admin_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}" 
   exit_code=$?
   set -e
   
   # shellcheck disable=SC2181
   if [ 194 -eq "${exit_code}" ]
   then 
      # Clear home directory    
      ssh_run_remote_command 'rm -f -R /home/ec2-user/*' \
                   "${private_key}" \
                   "${admin_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}"   
                   
      echo 'Rebooting instance ...'    
      set +e 
      ssh_run_remote_command 'reboot' \
                   "${private_key}" \
                   "${admin_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}"
      set -e
   else
      echo 'Error running delete_admin_website.sh'
      exit 1
   fi                   

   ## *** ##
   ## SSH ##
   ## *** ##

   if [[ -z "${admin_sgp_id}" ]]
   then
      echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group not found"
   else
      revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
      echo 'Revoked SSH access' 
   fi   
fi

# Clearing local files
rm -rf "${TMP_DIR}"/admin

echo 'Admin website deleted'
echo

