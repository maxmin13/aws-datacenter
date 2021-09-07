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

WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='webphp.http.virtualhost.maxmin.it.conf' 
APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
WEBSITE_DOCROOT_ID='webphp<ID>.maxmin.it'

if [[ $# -lt 1 ]]
then
   echo 'ERROR: missing mandatory arguments..'
   exit 1
else
   webphp_id="${1}"
   export webphp_id="${1}"
fi

webphp_nm="${WEBPHP_INST_NM/<ID>/${webphp_id}}"
webphp_keypair_nm="${WEBPHP_INST_KEY_PAIR_NM/<ID>/${webphp_id}}"
webphp_sgp_nm="${WEBPHP_INST_SEC_GRP_NM/<ID>/${webphp_id}}"
website_docroot_id="${WEBSITE_DOCROOT_ID/<ID>/${webphp_id}}"
webphp_dir=webphp"${webphp_id}"

echo '****************'
echo "Webphp website ${webphp_id}" 
echo '****************'
echo

get_instance_id "${webphp_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Webphp box not found.'
else
   instance_st="$(get_instance_state "${webphp_nm}")"
   echo "* Webphp box ID: ${instance_id} (${instance_st})."
fi

sgp_id="$(get_security_group_id "${webphp_sgp_nm}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: Webphp security group not found.'
else
   echo "* Webphp security group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Webphp public IP address not found'
else
   echo "* Webphp public IP address: ${eip}."
fi

loadbalancer_sgp_id="$(get_security_group_id "${LBAL_INST_SEC_GRP_NM}")"

if [[ -z "${loadbalancer_sgp_id}" ]]
then
   echo '* WARN: load balancer security group not found'
else
   echo "* load balancer security group ID: ${loadbalancer_sgp_id}."
fi

echo

# Clearing local files
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"
mkdir "${TMP_DIR}"/"${webphp_dir}"

##
## Load Balancer
##

if [[ -n "${loadbalancer_sgp_id}" && -n "${sgp_id}" ]]
then
   set +e
   revoke_access_from_security_group "${sgp_id}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" 'tcp' "${loadbalancer_sgp_id}" > /dev/null  2>&1
   set -e
     
   echo 'Load Balancer access to the website revoked.'
fi

if [[ -n "${instance_id}" && 'running' == "${instance_st}" ]]
then

   ##
   ## SSH Access
   ##
   
   set +e
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Granted SSH access to the Webphp box.'
   
   echo 'Uploading scripts to the Webphp box ...'

   remote_dir=/home/"${WEBPHP_INST_USER_NM}"/script
   key_pair_file="$(get_local_keypair_file_path "${webphp_keypair_nm}" "${WEBPHP_INST_ACCESS_DIR}")"
   wait_ssh_started "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}"

   ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${WEBPHP_INST_USER_NM}"  

   sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
       -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       -e "s/SEDwebsite_http_virtualhost_configSED/${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDwebsite_http_portSED/${WEBPHP_APACHE_WEBSITE_HTTP_PORT}/g" \
       -e "s/SEDwebsite_docroot_idSED/${website_docroot_id}/g" \
          "${TEMPLATE_DIR}"/webphp/website/delete_webphp_website_template.sh > "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh 
 
   echo 'delete_webphp_website.sh ready.'
      
   scp_upload_file "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh
          
   echo 'Deleting Webphp website ...'

   # Delete the Admin website
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_webphp_website.sh" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${WEBPHP_INST_USER_NM}" \
       "${WEBPHP_INST_USER_PWD}" 
        
   set +e     
           
   ssh_run_remote_command_as_root "${remote_dir}/delete_webphp_website.sh" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${WEBPHP_INST_USER_NM}" \
       "${WEBPHP_INST_USER_PWD}" 
      
   exit_code=$?	
   set -e

   # shellcheck disable=SC2181
   if [ 0 -eq "${exit_code}" ]
   then 
      echo 'Webphp website sucessfully removed.'

      # Clear remote directory    
      ssh_run_remote_command "rm -rf ${remote_dir:?}" \
          "${key_pair_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${WEBPHP_INST_USER_NM}" \
          "${WEBPHP_INST_USER_PWD}"  
  
      echo 'Cleared remote directory.'
   else
      echo 'ERROR: removing Webphp website.' 
      exit 1
   fi                 

   ## 
   ## SSH Access.
   ## 

   set +e
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null
   set -e
   
   echo 'Revoked SSH access to the Webphp box.' 
       
   # Removing temp files
   rm -rf "${TMP_DIR:?}"/"${webphp_dir}"  

   echo
   echo "Webphp website removed."
   echo
fi

