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

if [[ $# -lt 1 ]]
then
   echo 'Error: Missing mandatory arguments'
   exit 1
else
   webphp_id="${1}"
   export webphp_id="${1}"
fi

webphp_nm="${SERVER_WEBPHP_NM/<ID>/${webphp_id}}"
webphp_keypair_nm="${SERVER_WEBPHP_KEY_PAIR_NM/<ID>/${webphp_id}}"
webphp_sgp_nm="${SERVER_WEBPHP_SEC_GRP_NM/<ID>/${webphp_id}}"
website_docroot_id="${WEBSITE_DOCROOT_ID/<ID>/${webphp_id}}"
webphp_dir=webphp"${webphp_id}"
webphp_instance_id="$(get_instance_id "${webphp_nm}")"

echo '****************'
echo "WebPhp website ${webphp_id}" 
echo '****************'
echo

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

eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${eip}" ]]
then
   echo 'ERROR: WebPhp public IP address not found'
else
   echo "* WebPhp public IP address: '${eip}'"
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

if [[ -n "${eip}" && -n "${webphp_instance_id}" && -n "${webphp_sgp_id}" ]]
then
   ## *** ##
   ## SSH ##
   ## *** ##

   # Grant access from development machine.
   my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
   ##### TODO REMOVE THIS
   access_granted="$(check_access_from_cidr_is_granted "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0")"
   ##### access_granted="$(check_access_from_cidr_is_granted "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"

   if [[ -z "${access_granted}" ]]
   then
      ##### TODO REMOVE THIS
      allow_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
      #####allow_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
      echo "Granted SSH access to development machine" 
   else
      echo 'SSH access already granted to development machine' 
   fi
   
   echo 'Waiting for SSH to start'
   private_key="$(get_private_key_path "${webphp_keypair_nm}" "${WEBPHP_ACCESS_DIR}")"
   wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

   ## ******* ##
   ## Website ##
   ## ******* ##

   sed -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
       -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       -e "s/SEDvirtualhost_configSED/${WEBSITE_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDwebsite_docroot_idSED/${website_docroot_id}/g" \
          "${TEMPLATE_DIR}"/webphp/website/delete_webphp_website_template.sh > "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh 
 
   echo 'delete_webphp_website.sh ready'
   
   ## 
   ## Remote commands that have to be executed as priviledged user are run with sudo.
   ## The ec2-user sudo command has been configured with password.
   ##  
      
   echo 'Uploading files ...'
   remote_dir=/home/ec2-user/script

   ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
                "${private_key}" \
                "${eip}" \
                "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                "${DEFAUT_AWS_USER}"     
 
   scp_upload_files "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" "${remote_dir}" \
                "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh
          
   # Delete the WebPhp website
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_webphp_website.sh" \
                "${private_key}" \
                "${eip}" \
                "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                "${DEFAUT_AWS_USER}" \
                "${SERVER_WEBPHP_EC2_USER_PWD}" 
             
   set +e  
   ssh_run_remote_command_as_root "${remote_dir}/delete_webphp_website.sh" \
                "${private_key}" \
                "${eip}" \
                "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                "${DEFAUT_AWS_USER}" \
                "${SERVER_WEBPHP_EC2_USER_PWD}" 
   exit_code=$?
   set -e

   # shellcheck disable=SC2181
   if [ 194 -eq "${exit_code}" ]
   then 
      # Clear home directory    
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
   ##### TODO REMOVE THIS
   revoke_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
   #revoke_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access' 
fi   

# Clearing local files
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"

echo "Website ${webphp_id} delete" 
echo

