#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Deploy the admin website

APACHE_DOC_ROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
PUBLIC_VIRTUALHOST_CONFIG_FILE='public.virtualhost.maxmin.it.conf' 
ADMIN_SITE_ARCHIVE='admin.zip'

echo '*************'
echo 'Admin website'
echo '*************'
echo

admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_instance_id}" ]]
then
   echo "Error: Instance '${SERVER_ADMIN_NM}' not found"
   exit 1
else
   echo "* Admin instance ID: '${admin_instance_id}'"
fi

adm_sgp_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -z "${adm_sgp_id}" ]]
then
   echo 'ERROR: The Admin security group not found'
   exit 1
else
   echo "* Admin Security Group ID: '${adm_sgp_id}'"
fi

admin_eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_eip}" ]]
then
   echo 'ERROR: Admin public IP address not found'
   exit 1
else
   echo "* Admin public IP address: '${admin_eip}'"
fi

echo
echo 'Deploying the Admin website ...'

# Clear old files
rm -rf "${TMP_DIR}"/admin
mkdir "${TMP_DIR}"/admin

## *** ##
## SSH ##
## *** ##

# Check if the Admin Security Group grants access from the development machine through SSH port
my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
   
if [[ -z "${access_granted}" ]]
then
   allow_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
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
    -e "s/SEDadmin_archiveSED/${ADMIN_SITE_ARCHIVE}/g" \
    -e "s/SEDapache_doc_root_dirSED/$(escape ${APACHE_DOC_ROOT_DIR})/g" \
    -e "s/SEDadmin_domain_nameSED/${SERVER_ADMIN_HOSTNAME}/g" \
    -e "s/SEDvirtual_host_configSED/${PUBLIC_VIRTUALHOST_CONFIG_FILE}/g" \
       "${TEMPLATE_DIR}"/admin/website/install_admin_website_template.sh > "${TMP_DIR}"/admin/install_admin_website.sh  

## Website 

cd "${TMP_DIR}"/admin || exit

# Prepare the zip file with the Admin site source files.
cp -R "${ADMIN_SRC_DIR}"/* .

# Tell the admin website it's running on AWS and
# insert the email to send from
sed -i -e "s/SEDis_devSED/0/g" \
       -e "s/SEDsend_email_fromSED/${SERVER_ADMIN_EMAIL}/g" \
           init.php 

echo 'Preparing the archive with the Admin site source files ...'
zip -r "${ADMIN_SITE_ARCHIVE}" *.php *.css > /dev/null 2>&1
echo 'Admin archive completed'

## Virtual host 
       
# Download the virtualhost file from the server.
scp_download_file "${private_key}" \
                  "${admin_eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}" \
                  "${APACHE_SITES_AVAILABLE_DIR}"/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" \
                  "${TMP_DIR}"/admin   

echo 'Public virtualhost configuration file downloaded'
   
# Enable the admin site.                                     
add_alias_to_virtual_host 'admin' \
                  "${APACHE_DOC_ROOT_DIR}" \
                  "${SERVER_ADMIN_HOSTNAME}" \
                  "${TMP_DIR}"/admin/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" 
                            
echo 'Added Admin web site to the enabled virtualhosts'                                          
 
scp_upload_files "${private_key}" "${admin_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
                  "${TMP_DIR}"/admin/"${ADMIN_SITE_ARCHIVE}" \
                  "${TMP_DIR}"/admin/"${PUBLIC_VIRTUALHOST_CONFIG_FILE}" \
                  "${TMP_DIR}"/admin/install_admin_website.sh 

echo "Installing Admin website ..."

ssh_run_remote_command 'chmod +x install_admin_website.sh' \
                  "${private_key}" \
                  "${admin_eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}" \
                  "${SERVER_ADMIN_EC2_USER_PWD}"

set +e                
ssh_run_remote_command './install_admin_website.sh' \
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
   # Clear remote home directory    
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
   echo 'Error running install_admin_website.sh'
   exit 1
fi
                                   
## *** ##
## SSH ##
## *** ##

if [[ -z "${adm_sgp_id}" ]]
then
   echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group not found"
else
   revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access' 
fi

## ******** ##
## Clearing ##
## ******** ##

# Clear local files
rm -rf "${TMP_DIR}"/admin

echo "Admin website deployed at: '${admin_eip}'" 
echo

