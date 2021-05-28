#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Makes and run an Admin box instance, 
# The instance is built from the shared base 
# Linux hardened image.
# SSH is on 38142.
# No root access by default.
# Changed ec2-user password.
# Set ec2-user sudo with password.
# 
# Program installed: 
# rsyslog receiver for all logs; 
# Admin website; 
# Loganalyzer; 
# M/Monit; 
# javaMail;
# phpMyAdmin;
#
###############################################

APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_USER='apache'
PHPMYADMIN_DOCROOT_ID='phpmyadmin.maxmin.it'
PHPMYADMIN_VIRTUALHOST_CONFIG_FILE='phpmyadmin.virtualhost.maxmin.it.conf'
LOGANALYZER_DOCROOT_ID='loganalyzer.maxmin.it'
LOGANALYZER_VIRTUALHOST_CONFIG_FILE='loganalyzer.virtualhost.maxmin.it.conf'
MONIT_DOCROOT_ID='monit.maxmin.it'
MONIT_VIRTUALHOST_CONFIG_FILE='monit.virtualhost.maxmin.it.conf'
MMONIT_INSTALL_DIR='/opt/mmonit'
webphp_dir='admin'

echo '*********'
echo 'Certbot'
echo '*********'
echo

admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"
vpc_id="$(get_vpc_id "${VPC_NM}")"
subnet_id="$(get_subnet_id "${SUBNET_MAIN_NM}")"
db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"
db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"
shared_base_ami_id="$(get_image_id "${SHARED_BASE_AMI_NM}")"
eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"


# Removing old files
rm -rf "${TMP_DIR:?}"/admin
mkdir "${TMP_DIR}"/admin

private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}")"
my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
adm_sg_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"


allow_access_from_cidr "${adm_sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"

#############################################################################

CERTBOT_VIRTUALHOST_CONFIG_FILE='certbot.virtualhost.maxmin.it.conf'
CERTBOT_DOCROOT_ID='certbot.maxmin.it'

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       "${TEMPLATE_DIR}"/ssl/certbot/install_certbot_template.sh > "${TMP_DIR}"/admin/install_certbot.sh 
 
echo 'install_certbot.sh ready' 

#<VirtualHost *:80>
#    DocumentRoot "/var/www/html"
#    ServerName "example.com"
#    ServerAlias "www.example.com"
#</VirtualHost>

create_virtualhost_configuration_file "${TMP_DIR}"/admin/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" \
                           '*' \
                           "${SERVER_ADMIN_APACHE_CERTBOT_PORT}" \
                           "${SERVER_ADMIN_HOSTNAME}" \
                           "${APACHE_DOCROOT_DIR}" \
                           "${CERTBOT_DOCROOT_ID}"                                       
                                       
add_alias_to_virtualhost "${TMP_DIR}"/admin/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" \
                           'www.example.com' \
                           "${APACHE_DOCROOT_DIR}" \
                           "${CERTBOT_DOCROOT_ID}" \
                           'www.example.com' 

echo "Monit ${MONIT_VIRTUALHOST_CONFIG_FILE} ready"   

## 
## Remote commands that have to be executed as priviledged user are run with sudo.
## By AWS default, sudo has not password.
## 

echo 'Uploading the scripts to the admin server ...'
remote_dir=/home/ec2-user/script

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
                           "${private_key}" \
                           "${eip}" \
                           "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                           "${DEFAUT_AWS_USER}"  

scp_upload_files "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" "${remote_dir}" \
                          "${TMP_DIR}"/admin/install_certbot.sh 
                          
                          ## "${TEMPLATE_DIR}"/ssl/certbot/certbot_cron_job.sh
                
echo 'Scripts uploaded'

###########################################################################################################

echo 'Installing the admin modules ...'

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_admin.sh" \
                           "${private_key}" \
                           "${eip}" \
                           "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                           "${DEFAUT_AWS_USER}"

set +e                
ssh_run_remote_command_as_root "${remote_dir}/install_admin.sh" \
                           "${private_key}" \
                           "${eip}" \
                           "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                           "${DEFAUT_AWS_USER}"                          
exit_code=$?
set -e

echo 'Admin modules installed'

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
   echo 'ERROR: running install_admin.sh'
   exit 1
fi
