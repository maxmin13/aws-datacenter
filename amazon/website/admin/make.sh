#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Deploy the admin website

APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
WEBSITE_VIRTUALHOST_CONFIG_FILE='admin.virtualhost.maxmin.it.conf' 
WEBSITE_DOCROOT_ID='admin.maxmin.it'
WEBSITE_ARCHIVE='admin.zip'

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

eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo 'ERROR: Admin public IP address not found'
   exit 1
else
   echo "* Admin public IP address: '${eip}'"
fi

echo
echo 'Deploying the Admin website ...'

# Clear old files
rm -rf "${TMP_DIR:?}"/admin
mkdir "${TMP_DIR}"/admin

## *** ##
## SSH ##
## *** ##

# Check if the Admin Security Group grants access from the development machine through SSH port
my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
##### TODO REMOVE THIS
access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0")"
##### access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
   
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

sed -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDwebsite_archiveSED/${WEBSITE_ARCHIVE}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDwebsite_docroot_idSED/${WEBSITE_DOCROOT_ID}/g" \
    -e "s/SEDwebsite_virtualhost_fileSED/${WEBSITE_VIRTUALHOST_CONFIG_FILE}/g" \
       "${TEMPLATE_DIR}"/admin/website/install_admin_website_template.sh > "${TMP_DIR}"/admin/install_admin_website.sh  

echo 'install_admin_website.sh ready'

## Website source files

cd "${TMP_DIR}"/admin || exit
cp -R "${ADMIN_SRC_DIR}"/* ./

# Tell the admin website it's running on AWS and
# insert the email to send from
sed -i -e "s/SEDis_devSED/0/g" \
       -e "s/SEDsend_email_fromSED/${SERVER_ADMIN_EMAIL}/g" \
           init.php 

echo 'Preparing the archive with the Admin site source files ...'
zip -r "${WEBSITE_ARCHIVE}" ./*.php ./*.css > /dev/null 2>&1
echo "${WEBSITE_ARCHIVE} ready"

# Website virtualhost file.
create_virtualhost_configuration_file '*' \
                         "${SERVER_ADMIN_APACHE_WEBSITE_PORT}" \
                         "${SERVER_ADMIN_HOSTNAME}" \
                         "${APACHE_DOCROOT_DIR}" \
                         "${WEBSITE_DOCROOT_ID}" \
                         "${TMP_DIR}"/admin/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}"                              
                            
add_alias_to_virtualhost 'admin' \
                         "${APACHE_DOCROOT_DIR}" \
                         "${WEBSITE_DOCROOT_ID}" \
                         "${TMP_DIR}"/admin/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}"                        
                            
echo "${WEBSITE_VIRTUALHOST_CONFIG_FILE} ready"  

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
                         "${TMP_DIR}"/admin/"${WEBSITE_ARCHIVE}" \
                         "${TMP_DIR}"/admin/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}" \
                         "${TMP_DIR}"/admin/install_admin_website.sh 

echo 'Installing Admin website ...'

ssh_run_remote_command_as_root "chmod +x "${remote_dir}"/install_admin_website.sh" \
                         "${private_key}" \
                         "${eip}" \
                         "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                         "${DEFAUT_AWS_USER}" \
                         "${SERVER_ADMIN_EC2_USER_PWD}"

set +e                
ssh_run_remote_command_as_root "${remote_dir}/install_admin_website.sh" \
                         "${private_key}" \
                         "${eip}" \
                         "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                         "${DEFAUT_AWS_USER}" \
                         "${SERVER_ADMIN_EC2_USER_PWD}"                         
exit_code=$?	
set -e

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
                         "${SERVER_ADMIN_EC2_USER_PWD}" > /dev/null
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
   ##### TODO REMOVE THIS
   revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
   #####revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access' 
fi

## ******** ##
## Clearing ##
## ******** ##

# Clear local files
rm -rf "${TMP_DIR:?}"/admin

echo "Admin website deployed at: '${eip}'" 
echo

