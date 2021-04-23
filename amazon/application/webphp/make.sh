#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Deploy the WebPhp website
#
# parameters <N> where this is the Nth web box 
# (1-5)
#
# GLOBAL: webphp_id, required
###############################################

PUBLIC_VIRTUALHOST_CONFIG_FILE='public.virtualhost.maxmin.it.conf' 
PHPINCLUDE_ARCHIVE='phpinclude.zip'
HTDOCS_ARCHIVE='htdocs.zip'
APACHE_DOC_ROOT_DIR='/var/www/html'
APACHE_INSTALL_DIR='/etc/httpd'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_JAIL_DIR='/jail'

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
echo 'Deploying the WebPhp website ...'

# Clear old files
# shellcheck disable=SC2115
rm -rf "${TMP_DIR}"/"${webphp_dir}"
mkdir "${TMP_DIR}"/"${webphp_dir}"

## *** ##
## SSH ##
## *** ##

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
       "${TEMPLATE_DIR}"/webphp/website/install_webphp_website_template.sh > "${TMP_DIR}"/"${webphp_dir}"/install_webphp_website.sh  

## Source files
cd "${TMP_DIR}"/"${webphp_dir}" || exit
cp -R "${WEBPHP_SRC_DIR}"/* .

if [[ 'development' == "${ENV}" ]]
then
   ## Configuration files.
   cd "${TMP_DIR}"/"${webphp_dir}"/phpinclude || exit
   
   # Set: 
   # - development environment
   # - email address
   # - no redirect from HTTP to HTTPS
   sed -i -e "s/SEDis_devSED/0/g" \
          -e "s/SEDsend_email_fromSED/${SERVER_WEBPHP_EMAIL}/g" \
          -e "s/SEDrequire_sslSED/0/g" \
              globalvariables.php 

elif [[ 'production' == "${ENV}" ]]
then
   ## TODO 
   echo 'production'
fi 

## Prepare the archives.
echo 'Preparing the archives with the WebPhp site source files ...'

cd "${TMP_DIR}"/"${webphp_dir}"/htdocs || exit
zip -r ../"${HTDOCS_ARCHIVE}" * > /dev/null 2>&1
cd "${TMP_DIR}"/"${webphp_dir}"/phpinclude || exit
zip ../"${PHPINCLUDE_ARCHIVE}" * > /dev/null 2>&1

echo 'WebPhp archives completed'
       
# Download the virtualhost file from the server.
scp_download_file "${private_key}" \
                  "${webphp_eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}" \
                  "${APACHE_SITES_AVAILABLE_DIR}"/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" \
                  "${TMP_DIR}"/"${webphp_dir}" 

echo 'Public virtualhost configuration file downloaded'
   
# Enable the webphp site.                                     
#add_alias_to_virtual_host 'admin' \
#                  "${APACHE_DOC_ROOT_DIR}" \
#                  "${SERVER_ADMIN_HOSTNAME}" \
#                  "${TMP_DIR}"/"${webphp_dir}"/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" 
                            
echo 'Added WebPhp web site to the enabled virtualhosts'

scp_upload_files "${private_key}" "${webphp_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
                  "${TMP_DIR}"/"${webphp_dir}"/"${HTDOCS_ARCHIVE}" \
                  "${TMP_DIR}"/"${webphp_dir}"/"${PHPINCLUDE_ARCHIVE}" \
                  "${TMP_DIR}"/"${webphp_dir}"/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" \
                  "${TMP_DIR}"/"${webphp_dir}"/install_webphp_website.sh 

echo "Installing WebPhp website ..."

ssh_run_remote_command 'chmod +x install_webphp_website.sh' \
                  "${private_key}" \
                  "${webphp_eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}" \
                  "${SERVER_WEBPHP_EC2_USER_PWD}"

set +e                
ssh_run_remote_command './install_webphp_website.sh' \
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
   # Clear remote home directory    
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
   echo 'Error running install_webphp_website.sh'
   exit 1
fi
                                   
## *** ##
## SSH ##
## *** ##

if [[ -z "${webphp_sgp_id}" ]]
then
   echo "'${webphp_sgp_nm}' WebPhp Security Group not found"
else
   revoke_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access' 
fi

## ******** ##
## Clearing ##
## ******** ##

# Clear local files
rm -rf "${TMP_DIR}"/"${webphp_dir}"

echo "WebPhp website deployed at: '${webphp_eip}'" 
echo

