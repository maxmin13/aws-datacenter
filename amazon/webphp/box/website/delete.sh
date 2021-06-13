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
   echo 'ERROR: missing mandatory arguments..'
   exit 1
else
   webphp_id="${1}"
   export webphp_id="${1}"
fi

webphp_nm="${SRV_WEBPHP_NM/<ID>/${webphp_id}}"
webphp_keypair_nm="${SRV_WEBPHP_KEY_PAIR_NM/<ID>/${webphp_id}}"
webphp_sgp_nm="${SRV_WEBPHP_SEC_GRP_NM/<ID>/${webphp_id}}"
website_docroot_id="${WEBSITE_DOCROOT_ID/<ID>/${webphp_id}}"
webphp_dir=webphp"${webphp_id}"

echo '****************'
echo "Webphp website ${webphp_id}" 
echo '****************'
echo

instance_id="$(get_instance_id "${webphp_nm}")"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Webphp box not found.'
   
   exit 1
fi

sgp_id="$(get_security_group_id "${webphp_sgp_nm}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: Webphp Security Group not found.'
   
   exit 1
else
   echo "* Webphp Security Group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Webphp public IP address not found'
   
   exit 1
else
   echo "* Webphp public IP address: ${eip}."
fi

loadbalancer_sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -z "${loadbalancer_sgp_id}" ]]
then
   echo '* ERROR: Load Balancer Security Group not found'
   
   exit 1
else
   echo "* Load Balancer Security Group ID: ${loadbalancer_sgp_id}."
fi

echo

# Clearing local files
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"
mkdir "${TMP_DIR}"/"${webphp_dir}"

##
## Load Balancer
##

lbal_granted="$(check_access_from_security_group_is_granted "${sgp_id}" "${SRV_WEBPHP_APACHE_WEBSITE_PORT}" "${loadbalancer_sgp_id}")"

if [[ -n "${lbal_granted}" ]]
then
   revoke_access_from_security_group "${sgp_id}" "${SRV_WEBPHP_APACHE_WEBSITE_PORT}" "${loadbalancer_sgp_id}"
     
   echo 'Load Balancer access to the website revoked.'
fi

##
## SSH Access
##

granted_ssh="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_ssh}" ]]
then
   echo 'WARN: SSH access to the Webphp box already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
  
   echo 'Granted SSH access to the Webphp box.'
fi

echo 'Uploading scripts to the Webphp box ...'

remote_dir=/home/"${SRV_WEBPHP_USER_NM}"/script
key_pair_file="$(get_keypair_file_path "${webphp_keypair_nm}" "${SRV_WEBPHP_ACCESS_DIR}")"
wait_ssh_started "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_WEBPHP_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_WEBPHP_USER_NM}"  

sed -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDvirtualhost_configSED/${WEBSITE_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_docroot_idSED/${website_docroot_id}/g" \
       "${TEMPLATE_DIR}"/webphp/website/delete_webphp_website_template.sh > "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh 
 
echo 'delete_webphp_website.sh ready.'
      
scp_upload_file "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_WEBPHP_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${webphp_dir}"/delete_webphp_website.sh
          
echo 'Deleting Webphp website ...'

# Delete the Admin website
ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_webphp_website.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_WEBPHP_USER_NM}" \
    "${SRV_WEBPHP_USER_PWD}" 
        
set +e     
           
ssh_run_remote_command_as_root "${remote_dir}/delete_webphp_website.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_WEBPHP_USER_NM}" \
    "${SRV_WEBPHP_USER_PWD}" 
      
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
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_WEBPHP_USER_NM}" \
       "${SRV_WEBPHP_USER_PWD}"  
  
   echo 'Cleared remote directory.'
else
   echo 'ERROR: removing Webphp website.'
   
   exit 1
fi                 

## 
## SSH Access.
## 

if [[ -n "${granted_ssh}" ]]
then
   # Revoke SSH access from the development machine
   revoke_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo 'Revoked SSH access to the Webphp box.' 
fi
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"  

echo
echo "Webphp website removed."
echo
