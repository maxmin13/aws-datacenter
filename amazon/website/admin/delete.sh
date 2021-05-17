#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
WEBSITE_VIRTUALHOST_CONFIG_FILE='admin.virtualhost.maxmin.it.conf' 
WEBSITE_DOCROOT_ID='admin.maxmin.it'

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

adm_sgp_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -z "${adm_sgp_id}" ]]
then
   echo 'The Admin security group not found'
else
   echo "* Admin Security Group ID: '${adm_sgp_id}'"
fi

eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo 'Admin public IP address not found'
else
   echo "* Admin public IP address: '${eip}'"
fi

echo
echo 'Deleting Admin website ...'

# Clearing local files
rm -rf "${TMP_DIR:?}"/admin
mkdir "${TMP_DIR}"/admin

if [[ -n "${eip}" && -n "${admin_instance_id}" && -n "${adm_sgp_id}" ]]
then
   ## *** ##
   ## SSH ##
   ## *** ##
   
   # Check if the Admin Security Group grants access from the development machine through SSH port
   my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
   ##### TODO REMOVE THIS
   access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0")"
   #####access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
   
   if [[ -z "${access_granted}" ]]
   then
      ##### TODO REMOVE THIS
      allow_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
      #####allow_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
      echo "Granted SSH access to development machine" 
   else
      echo 'SSH access already granted to development machine'    
   fi
   
   echo 'Waiting for SSH to start'
   private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}")" 
   wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"   
   
   ## ******* ##
   ## Modules ##
   ## ******* ##

   sed -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
       -e "s/SEDwebsite_docroot_idSED/${WEBSITE_DOCROOT_ID}/g" \
       -e "s/SEDwebsite_virtualhost_fileSED/${WEBSITE_VIRTUALHOST_CONFIG_FILE}/g" \
          "${TEMPLATE_DIR}"/admin/website/delete_admin_website_template.sh > "${TMP_DIR}"/admin/delete_admin_website.sh
          
   echo 'delete_admin_website.sh ready' 
   
   ## 
   ## Remote commands that have to be executed as priviledged user are run with sudo.
   ## The ec2-user sudo command has been configured with password.
   ##    
   
   echo 'Uploading files to Admin server ...'
   remote_dir=/home/ec2-user/script

   ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir ${remote_dir}" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"     
                                    
   scp_upload_files "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" "${remote_dir}" \
                   "${TMP_DIR}"/admin/delete_admin_website.sh 

   # Delete the Admin website
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_admin_website.sh" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}" 
   
   echo "Deleting Admin website ..."
             
   set +e              
   ssh_run_remote_command_as_root "${remote_dir}/delete_admin_website.sh" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}" 
   exit_code=$?
   set -e
   
   echo "Admin website deleted"
   
   # shellcheck disable=SC2181
   if [ 194 -eq "${exit_code}" ]
   then 
      # Clear remote directory    
      ssh_run_remote_command "rm -rf ${remote_dir:?}" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"   
                   
      echo 'Rebooting instance ...'    
      set +e 
      ssh_run_remote_command_as_root 'reboot' \
                   "${private_key}" \
                   "${eip}" \
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

   if [[ -z "${adm_sgp_id}" ]]
   then
      echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group not found"
   else
        ##### TODO REMOVE THIS
        revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
        #####revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
        echo 'Revoked SSH access'
   fi   
fi

# Clearing local files
rm -rf "${TMP_DIR:?}"/admin

echo 'Admin website deleted'
echo

