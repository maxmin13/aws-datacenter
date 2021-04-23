#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

PUBLIC_VIRTUALHOST_CONFIG_FILE='public.virtualhost.maxmin.it.conf' 
PHPINCLUDE_ARCHIVE='phpinclude.zip'
HTDOCS_ARCHIVE='htdocs.zip'
APACHE_DOC_ROOT_DIR='/var/www/html'
APACHE_INSTALL_DIR='/etc/httpd'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_JAIL_DIR='/jail'

###############################################
# Delete the WebPhp website
#
# parameters <N> where this is the Nth web box 
# (1-5)
#
# GLOBAL: webphp_id, required
###############################################

echo '**************'
echo 'WebPhp website'
echo '**************'
echo

if [[ $# -lt 1 ]]
then
   echo 'Error: Missing mandatory arguments'
   exit 1
else
   export webphp_id="${1}"
   webphp_nm="${SERVER_WEBPHP_NM/<ID>/${webphp_id}}"
   webphp_hostname="${SERVER_WEBPHP_HOSTNAME/<ID>/${webphp_id}}"
   webphp_keypair_nm="${SERVER_WEBPHP_KEY_PAIR_NM/<ID>/${webphp_id}}"
   webphp_sgp_nm="${SERVER_WEBPHP_SEC_GRP_NM/<ID>/${webphp_id}}"
   webphp_db_user_nm="${DB_MMDATA_WEBPHP_USER_NM/<ID>/${webphp_id}}"
   webphp_dir=webphp"${webphp_id}"
fi

webphp_instance_id="$(get_instance_id "${webphp_nm}")"

if [[ -z "${webphp_instance_id}" ]]
then
   echo "Error: Instance '${webphp_nm}' not found"
   exit 1
fi

webphp_sgp_id="$(get_security_group_id "${webphp_sgp_nm}")"

if [[ -z "${webphp_sgp_id}" ]]
then
   echo 'ERROR: The WebPhp security group not found'
   exit 1
else
   echo "* WebPhp Security Group ID: '${webphp_sgp_id}'"
fi

webphp_eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${webphp_eip}" ]]
then
   echo 'ERROR: WebPhp public IP address not found'
   exit 1
else
   echo "* WebPhp public IP address: '${webphp_eip}'"
fi

echo
echo 'Deleting the WebPhp website ...'

# Clearing local files
rm -rf "${TMP_DIR}"/"${webphp_dir}"
mkdir "${TMP_DIR}"/"${webphp_dir}"

if [[ -n "${webphp_eip}" && -n "${webphp_instance_id}" && -n "${webphp_sgp_id}" ]]
then
   ## *** ##
   ## SSH ##
   ## *** ##
   
   ## Get the Key Pair to SSH the box
   key_pair_id="$(get_key_pair_id "${webphp_keypair_nm}")"
  
   # Check if the WebPhp Security Group grants access from the development machine through SSH port
   my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
   access_granted="$(check_access_from_cidr_is_granted "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
   
   if [[ -z "${access_granted}" ]]
   then
      allow_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
      echo "Granted SSH access to development machine" 
   else
      echo 'SSH access already granted to development machine'    
   fi
   
   echo 'Waiting for SSH to start'
   private_key="$(get_private_key_path "${webphp_keypair_nm}" "${WEBPHP_CREDENTIALS_DIR}")"
   wait_ssh_started "${private_key}" "${webphp_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"
   
   ## ******* ##
   ## Website ##
   ## ******* ##

   sed -e "s/SEDapache_doc_root_dirSED/$(escape ${APACHE_DOC_ROOT_DIR})/g" \
       -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
       -e "s/SEDapache_jail_dirSED/$(escape ${APACHE_JAIL_DIR})/g" \
       -e "s/SEDvirtual_host_configSED/${PUBLIC_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDphpinclude_achiveSED/${PHPINCLUDE_ARCHIVE}/g" \
       -e "s/SEDhtdocs_archiveSED/${HTDOCS_ARCHIVE}/g" \
       -e "s/SEDwebphp_domain_nameSED/${webphp_hostname}/g" \
          "${TEMPLATE_DIR}"/webphp/website/delete_webphp_website_template.sh > "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh    
   
   # Download the virtualhost file from the server.
   scp_download_file "${private_key}" \
                     "${webphp_eip}" \
                     "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                     "${DEFAUT_AWS_USER}" \
                     "${APACHE_SITES_AVAILABLE_DIR}"/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" \
                     "${TMP_DIR}"/"${webphp_dir}"   

   echo 'Virtualhost configuration file downloaded'

#   # Disable the WebPhp website.                                     
#   remove_alias_from_virtual_host 'admin' \
#                                    "${APACHE_DOC_ROOT_DIR}" \
#                                    "${webphp_hostname}" \
#                                    "${TMP_DIR}"/"${webphp_dir}"/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" 
                                    
   echo 'Removed WebPhp web site from the enabled virtualhosts'                                 
   
   scp_upload_files "${private_key}" "${webphp_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
                   "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh \
                   "${TMP_DIR}"/"${webphp_dir}"/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" 

   # Delete the WebPhp website
   ssh_run_remote_command 'chmod +x delete_webphp_website.sh' \
                   "${private_key}" \
                   "${webphp_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_WEBPHP_EC2_USER_PWD}" 
             
   set +e              
   ssh_run_remote_command './delete_webphp_website.sh' \
                   "${private_key}" \
                   "${webphp_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_WEBPHP_EC2_USER_PWD}" 
   exit_code=$?
   set -e
   
   # shellcheck disable=SC2181
   if [ 194 -eq "${exit_code}" ]
   then 
      # Clear home directory    
      ssh_run_remote_command 'rm -f -R /home/ec2-user/*' \
                   "${private_key}" \
                   "${webphp_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_WEBPHP_EC2_USER_PWD}"   
                   
      echo 'Rebooting instance ...'    
      set +e 
      ssh_run_remote_command 'reboot' \
                   "${private_key}" \
                   "${webphp_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_WEBPHP_EC2_USER_PWD}"
      set -e
   else
      echo 'Error running delete_webphp_website.sh'
      exit 1
   fi                

   ## *** ##
   ## SSH ##
   ## *** ##

   if [[ -z "${webphp_sgp_nm}" ]]
   then
      echo "'${webphp_sgp_nm}' WebPhp Security Group not found"
   else
      revoke_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
      echo 'Revoked SSH access' 
   fi   
fi

# Clearing local files
rm -rf "${TMP_DIR}"/"${webphp_dir}"

echo 'WebPhp website deleted'
echo

