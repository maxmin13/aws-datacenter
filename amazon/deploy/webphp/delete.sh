#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Delete the WebPhp website
#
# parameters <N> where this is the Nth web box 
# (1-5)
#
# GLOBAL: webphp_id, required
###############################################

WEBSITE_VIRTUALHOST_CONFIG_FILE='webphp.virtualhost.maxmin.it.conf'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
WEBSITE_DOCROOT_ID='webphp<ID>.maxmin.it'

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
   webphp_keypair_nm="${SERVER_WEBPHP_KEY_PAIR_NM/<ID>/${webphp_id}}"
   webphp_sgp_nm="${SERVER_WEBPHP_SEC_GRP_NM/<ID>/${webphp_id}}"
   website_docroot_id="${WEBSITE_DOCROOT_ID/<ID>/${webphp_id}}"
   webphp_dir=webphp"${webphp_id}"
   webphp_instance_id="$(get_instance_id "${webphp_nm}")"
fi

if [[ -z "${webphp_instance_id}" ]]
then
   echo "Instance '${webphp_nm}' not found"
else
   echo "* Admin instance ID: '${webphp_instance_id}'"
fi

webphp_sgp_id="$(get_security_group_id "${webphp_sgp_nm}")"

if [[ -z "${webphp_sgp_id}" ]]
then
   echo 'The WebPhp security group not found'
else
   echo "* WebPhp Security Group ID: '${webphp_sgp_id}'"
fi

webphp_eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${webphp_eip}" ]]
then
   echo 'ERROR: WebPhp public IP address not found'
else
   echo "* WebPhp public IP address: '${webphp_eip}'"
fi

echo
echo "Deleting website ${webphp_id} ..." 

# Clearing local files
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"
mkdir "${TMP_DIR}"/"${webphp_dir}"

loadbalancer_sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -n "${loadbalancer_sgp_id}" && -n "${webphp_sgp_id}" ]]
then
   granted="$(check_access_from_group_is_granted "${webphp_sgp_id}" "${SERVER_WEBPHP_APACHE_WEBSITE_PORT}" "${loadbalancer_sgp_id}")"
   if [[ -n "${granted}" ]]
   then
      # Revoke Load Balancer access to the website
      revoke_access_from_security_group "${webphp_sgp_id}" "${SERVER_WEBPHP_APACHE_WEBSITE_PORT}" "${loadbalancer_sgp_id}"
      echo 'Load Balancer access to the website revoked'
   fi
fi

if [[ -n "${webphp_eip}" && -n "${webphp_instance_id}" && -n "${webphp_sgp_id}" ]]
then
   ## *** ##
   ## SSH ##
   ## *** ##

   # Grant access from development machine.
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
   private_key="$(get_private_key_path "${webphp_keypair_nm}" "${WEBPHP_ACCESS_DIR}")"
   wait_ssh_started "${private_key}" "${webphp_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

   ## ******* ##
   ## Website ##
   ## ******* ##

   sed -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
       -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       -e "s/SEDvirtualhost_configSED/${WEBSITE_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDwebsite_docroot_idSED/${website_docroot_id}/g" \
          "${TEMPLATE_DIR}"/webphp/website/delete_webphp_website_template.sh > "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh 
 
   echo 'delete_webphp_website.sh ready'
 
   scp_upload_files "${private_key}" "${webphp_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
               "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh
          
          
   
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

# Clearing local files
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"

echo "Website ${webphp_id} delete" 
echo

