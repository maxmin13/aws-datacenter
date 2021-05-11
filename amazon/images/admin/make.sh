#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Makes an Admin box, from a Linux hardened 
# image.
# SSH is on 38142
# The Admin server includes: 
# rsyslog receiver for all logs; 
# Admin website; 
# Loganalyzer; 
# M/Monit; 
# javaMail;
# phpMyAdmin;
# 'root', 'ec2-user' and 'sudo' command have a 
# password after the install script is run.
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

echo '*********'
echo 'Admin box'
echo '*********'
echo

admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"

if [[ -n "${admin_instance_id}" ]]
then
   echo "Error: Instance '${SERVER_ADMIN_NM}' already created"
   exit 1
fi

vpc_id="$(get_vpc_id "${VPC_NM}")"
  
if [[ -z "${vpc_id}" ]]
then
   echo 'Error, VPC not found.'
   exit 1
else
   echo "* VPC ID: '${vpc_id}'"
fi

subnet_id="$(get_subnet_id "${SUBNET_MAIN_NM}")"

if [[ -z "${subnet_id}" ]]
then
   echo 'Error, Subnet not found.'
   exit 1
else
   echo "* Subnet ID: '${subnet_id}'"
fi

db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"
  
if [[ -z "${db_sg_id}" ]]
then
   echo "ERROR: The '${DB_MMDATA_SEC_GRP_NM}' Database Security Group not found"
   exit 1
else
   echo "* Database Security Group ID: ${db_sg_id}"
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo "Error: Database '${DB_MMDATA_NM}' Endpoint not found"
   exit 1
else
   echo "* Database Endpoint: ${db_endpoint}"
fi

shared_base_ami_id="$(get_image_id "${SHARED_BASE_AMI_NM}")"

if [[ -z "${shared_base_ami_id}" ]]
then
   echo "Error: Shared Base Image '${SHARED_BASE_AMI_NM}' not found"
   exit 1
else
   echo "* Shared Base Image ID: ${shared_base_ami_id}"
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/admin
mkdir "${TMP_DIR}"/admin

## ************ ##
## SSH Key Pair ##
## ************ ##

# Delete the local private-key and the remote public-key.
delete_key_pair "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}"

# Create a key pair to SSH into the instance.
create_key_pair "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}"
echo 'Created Admin Key Pair to SSH into the Instance, the Private Key is saved in the credentials directory'

private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}")"

## ************** ##
## Security Group ##
## ************** ##

my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
adm_sg_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -n "${adm_sg_id}" ]]
then
   echo 'ERROR: The Admin security group is already created'
   exit 1
fi
  
adm_sg_id="$(create_security_group "${vpc_id}" "${SERVER_ADMIN_SEC_GRP_NM}" \
                    'Admin security group')"

allow_access_from_cidr "${adm_sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
echo 'Created Admin Security Group'

## *************** ##
## Database access ##
## *************** ##

allow_access_from_security_group "${db_sg_id}" "${DB_MMDATA_PORT}" "${adm_sg_id}"
echo 'Granted access to Database'

## ************** ##
## Admin Instance ##
## ************** ##

echo "Creating '${SERVER_ADMIN_NM}' Admin Instance ..."

# The Admin instance is run from the secured Shared Image.
run_admin_instance "${shared_base_ami_id}" "${adm_sg_id}" "${subnet_id}"
admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"

## ********* ##
## Public IP ##
## ********* ##

echo 'Checking if there is any public IP avaiable in the account'
eip="$(get_public_ip_address_unused)"

if [[ -n "${eip}" ]]
then
   echo "Found '${eip}' unused public IP address"
else
   echo 'Not found any unused public IP address, a new one must be allocated'
   eip="$(allocate_public_ip_address)" 
   echo "The '${eip}' public IP address has been allocated to the account"
fi

associate_public_ip_address_to_instance "${eip}" "${admin_instance_id}"
echo "The '${eip}' public IP address has been associated with the Admin instance"

## ******* ##
## Modules ##
## ******* ##

echo 'Preparing the scripts to run on the server'

sed -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDserver_admin_hostnameSED/${SERVER_ADMIN_HOSTNAME}/g" \
    -e "s/SEDmmonit_archiveSED/${MMONIT_ARCHIVE}/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
    -e "s/SEDmonit_docroot_idSED/${MONIT_DOCROOT_ID}/g" \
    -e "s/SEDmonit_virtualhost_fileSED/${MONIT_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDphpmyadmin_docroot_idSED/${PHPMYADMIN_DOCROOT_ID}/g" \
    -e "s/SEDphpmyadmin_virtualhost_fileSED/${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDloganalyzer_archiveSED/${LOGANALYZER_ARCHIVE}/g" \
    -e "s/SEDloganalyzer_docroot_idSED/${LOGANALYZER_DOCROOT_ID}/g" \
    -e "s/SEDloganalyzer_virtualhost_fileSED/${LOGANALYZER_VIRTUALHOST_CONFIG_FILE}/g" \
       "${TEMPLATE_DIR}"/admin/install_admin_template.sh > "${TMP_DIR}"/admin/install_admin.sh

echo 'install_admin.sh ready'

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/install_apache_web_server_template.sh > "${TMP_DIR}"/admin/install_apache_web_server.sh 
 
echo 'install_apache_web_server.sh ready' 
 
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_FCGI_template.sh > "${TMP_DIR}"/admin/extend_apache_web_server_with_FCGI.sh    

echo 'extend_apache_web_server_with_FCGI.sh ready'
 
# Apache Web Server main configuration file.
sed -e "s/SEDserver_admin_hostnameSED/${SERVER_ADMIN_HOSTNAME}/g" \
    -e "s/SEDapache_monit_portSED/${SERVER_ADMIN_APACHE_MONIT_PORT}/g" \
    -e "s/SEDadmin_emailSED/${SERVER_ADMIN_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    -e "s/SEDdatabase_portSED/${DB_MMDATA_PORT}/g" \
    -e "s/SEDdatabase_user_adminrwSED/${DB_MMDATA_ADMIN_USER_NM}/g" \
    -e "s/SEDdatabase_password_adminrwSED/${DB_MMDATA_ADMIN_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/admin/httpd/httpd_template.conf > "${TMP_DIR}"/admin/httpd.conf

echo 'Apache httpd.conf ready'
   
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       -e "s/SEDenvironmentSED/${ENV}/g" \
       -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_SSL_module_template.sh > "${TMP_DIR}"/admin/extend_apache_web_server_with_SSL_module_template.sh       

echo 'extend_apache_web_server_with_SSL_module_template.sh ready'

#if [[ 'development' == "${ENV}" ]]
if 'true'
then
   # Apache Web Server SSL key generation script.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDkey_pwdSED/${SERVER_ADMIN_PRIV_KEY_PWD}/g" \
          "${TEMPLATE_DIR}"/ssl/gen-rsa_template.exp > "${TMP_DIR}"/admin/gen-rsa.sh

   echo 'Apache SSL gen-rsa.sh ready'

   # Apache Web Server remove the password protection from the key script.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDnew_key_fileSED/server.key.org/g" \
       -e "s/SEDkey_pwdSED/${SERVER_ADMIN_PRIV_KEY_PWD}/g" \
          "${TEMPLATE_DIR}"/ssl/remove-passphase_template.exp > "${TMP_DIR}"/admin/remove-passphase.sh   

   echo 'Apache SSL remove-passphase.sh ready'

   # Apache Web Server create self-signed Certificate script.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDcert_fileSED/server.crt/g" \
       -e "s/SEDcountrySED/${SERVER_ADMIN_CRT_COUNTRY_NM}/g" \
       -e "s/SEDstate_or_provinceSED/${SERVER_ADMIN_CRT_PROVINCE_NM}/g" \
       -e "s/SEDcitySED/${SERVER_ADMIN_CRT_CITY_NM}/g" \
       -e "s/SEDorganizationSED/${SERVER_ADMIN_CRT_ORGANIZATION_NM}/g" \
       -e "s/SEDunit_nameSED/${SERVER_ADMIN_CRT_UNIT_NM}/g" \
       -e "s/SEDcommon_nameSED/${SERVER_ADMIN_HOSTNAME}/g" \
       -e "s/SEDemail_addressSED/${SERVER_ADMIN_EMAIL}/g" \
          "${TEMPLATE_DIR}"/ssl/gen-selfsign-cert_template.exp > "${TMP_DIR}"/admin/gen-selfsign-cert.sh

   echo 'gen-selfsign-cert.sh ready'
   
   # Apache Web Server SSL configuration file.
   sed -e "s/SEDwebsite_portSED/${SERVER_ADMIN_APACHE_WEBSITE_PORT}/g" \
       -e "s/SEDphpmyadmin_portSED/${SERVER_ADMIN_APACHE_PHPMYADMIN_PORT}/g" \
       -e "s/SEDloganalyzer_portSED/${SERVER_ADMIN_APACHE_LOGANALYZER_PORT}/g" \
       -e "s/SEDssl_certificate_key_fileSED/server.key/g" \
       -e "s/SEDssl_certificate_fileSED/server.crt/g" \
          "${TEMPLATE_DIR}"/admin/httpd/ssl_template.conf > "${TMP_DIR}"/admin/ssl.conf 
          
   echo 'Apache ssl.conf ready'
                   
#elif [[ 'production' == "${ENV}" ]]
#then
else
   # TODO
   # TODO Use a certificate authenticated by a Certificate Authority.
   # TODO Enable SSLCertificateChainFile in ssl.conf
   # TODO        
   # TODO  sudo awk -i inplace '{if($1 == "#SSLCertificateChainFile"){$1="SSLCertificateChainFile"; print $0} else {print $0}}' "${TMP_DIR}"/admin/ssl.conf 
   
   echo 'Error: a production certificate is not available, use a developement self-signed one'
   exit 1        
fi

# Script that sets a password for 'ec2-user' user.
sed -e "s/SEDuser_nameSED/ec2-user/g" \
    -e "s/SEDuser_pwdSED/${SERVER_ADMIN_EC2_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/users/chp_user_template.exp > "${TMP_DIR}"/admin/chp_ec2-user.sh
  
echo 'Change ec2-user password chp_ec2-user.sh ready'

# Script that sets a password for 'root' user.
sed -e "s/SEDuser_nameSED/root/g" \
    -e "s/SEDuser_pwdSED/${SERVER_ADMIN_ROOT_PWD}/g" \
       "${TEMPLATE_DIR}"/users/chp_user_template.exp > "${TMP_DIR}"/admin/chp_root.sh
       
echo 'Change root password chp_root.sh ready'

# M/Monit systemctl service file
sed -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/admin/mmonit/mmonit_template.service > "${TMP_DIR}"/admin/mmonit.service 
       
echo 'M/Monit mmonit.service ready'
     
# M/Monit website configuration file (only on the Admin server).
sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
    -e "s/SEDserver_admin_private_ipSED/${SERVER_ADMIN_PRIVATE_IP}/g" \
    -e "s/SEDcollector_portSED/${SERVER_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDpublic_portSED/${SERVER_ADMIN_MMONIT_PUBLIC_PORT}/g" \
       "${TEMPLATE_DIR}"/admin/mmonit/server_template.xml > "${TMP_DIR}"/admin/server.xml
       
echo 'M/Monit server.xml ready'  

# Monit demon configuration file (runs on all servers).
sed -e "s/SEDhostnameSED/${SERVER_ADMIN_NM}/g" \
    -e "s/SEDmmonit_collector_portSED/${SERVER_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDapache_monit_portSED/${SERVER_ADMIN_APACHE_MONIT_PORT}/g" \
    -e "s/SEDadmin_emailSED/${SERVER_ADMIN_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/admin/monitrc_template > "${TMP_DIR}"/admin/monitrc 
       
echo 'Monit monitrc ready'  

# PhpMyAdmin configuration file.    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
       "${TEMPLATE_DIR}"/admin/config_inc_template.php > "${TMP_DIR}"/admin/config.inc.php
       
echo 'PhpMyAdmin config.inc.php ready'
                            
# Rsyslog configuration file.    
sed -e "s/SEDadmin_rsyslog_portSED/${SERVER_ADMIN_RSYSLOG_PORT}/g" \
       "${TEMPLATE_DIR}"/admin/rsyslog_template.conf > "${TMP_DIR}"/admin/rsyslog.conf   
       
echo 'Rsyslog rsyslog.conf ready'
       
# Monit Apache heartbeat virtualhost.                                     
create_virtualhost_configuration_file '127.0.0.1' \
                                       "${SERVER_ADMIN_APACHE_MONIT_PORT}" \
                                       "${SERVER_ADMIN_HOSTNAME}" \
                                       "${APACHE_DOCROOT_DIR}" \
                                       "${MONIT_DOCROOT_ID}" \
                                       "${TMP_DIR}"/admin/"${MONIT_VIRTUALHOST_CONFIG_FILE}"                                      
                                       
add_alias_to_virtualhost 'monit' \
                            "${APACHE_DOCROOT_DIR}" \
                            "${MONIT_DOCROOT_ID}" \
                            "${TMP_DIR}"/admin/"${MONIT_VIRTUALHOST_CONFIG_FILE}"
                            
echo "Monit ${MONIT_VIRTUALHOST_CONFIG_FILE} ready"                                                                                        

# phpmyadmin Virtual Host file.
create_virtualhost_configuration_file '*' \
                                       "${SERVER_ADMIN_APACHE_PHPMYADMIN_PORT}" \
                                       "${SERVER_ADMIN_HOSTNAME}" \
                                       "${APACHE_DOCROOT_DIR}" \
                                       "${PHPMYADMIN_DOCROOT_ID}" \
                                       "${TMP_DIR}"/admin/"${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE}"      
                                     
add_alias_to_virtualhost 'phpmyadmin' \
                            "${APACHE_DOCROOT_DIR}" \
                            "${PHPMYADMIN_DOCROOT_ID}" \
                            "${TMP_DIR}"/admin/"${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE}"                       

echo "PhpMyAdmin ${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE} ready"                             
                            
# loganalyzer Virtual Host file.
create_virtualhost_configuration_file '*' \
                                       "${SERVER_ADMIN_APACHE_LOGANALYZER_PORT}" \
                                       "${SERVER_ADMIN_HOSTNAME}" \
                                       "${APACHE_DOCROOT_DIR}" \
                                       "${LOGANALYZER_DOCROOT_ID}" \
                                       "${TMP_DIR}"/admin/"${LOGANALYZER_VIRTUALHOST_CONFIG_FILE}"                              
                            
add_alias_to_virtualhost 'loganalyzer' \
                            "${APACHE_DOCROOT_DIR}" \
                            "${LOGANALYZER_DOCROOT_ID}" \
                            "${TMP_DIR}"/admin/"${LOGANALYZER_VIRTUALHOST_CONFIG_FILE}"  
                            
echo "Loganalyzer ${LOGANALYZER_VIRTUALHOST_CONFIG_FILE} ready"                                    
  
echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

echo 'Uploading files ...'
scp_upload_files "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
                 "${TEMPLATE_DIR}"/common/php/install_php.sh \
                 "${TEMPLATE_DIR}"/common/php/php.ini \
                 "${TMP_DIR}"/admin/install_admin.sh \
                 "${TMP_DIR}"/admin/install_apache_web_server.sh \
                 "${TMP_DIR}"/admin/extend_apache_web_server_with_FCGI.sh \
                 "${TMP_DIR}"/admin/extend_apache_web_server_with_SSL_module_template.sh \
                 "${TMP_DIR}"/admin/ssl.conf \
                 "${TMP_DIR}"/admin/httpd.conf \
                 "${TEMPLATE_DIR}"/common/httpd/httpd-mpm.conf \
                 "${TEMPLATE_DIR}"/common/httpd/00-ssl.conf \
                 "${TEMPLATE_DIR}"/common/httpd/09-fcgid.conf \
                 "${TEMPLATE_DIR}"/common/httpd/10-fcgid.conf \
                 "${JAR_DIR}"/"${LOGANALYZER_ARCHIVE}" \
                 "${TMP_DIR}"/admin/"${LOGANALYZER_VIRTUALHOST_CONFIG_FILE}" \
                 "${TEMPLATE_DIR}"/admin/config.php \
                 "${JAR_DIR}"/"${MMONIT_ARCHIVE}" \
                 "${TMP_DIR}"/admin/monitrc \
                 "${TMP_DIR}"/admin/"${MONIT_VIRTUALHOST_CONFIG_FILE}" \
                 "${TMP_DIR}"/admin/mmonit.service \
                 "${TMP_DIR}"/admin/server.xml \
                 "${TMP_DIR}"/admin/chp_root.sh \
                 "${TMP_DIR}"/admin/chp_ec2-user.sh \
                 "${TMP_DIR}"/admin/gen-selfsign-cert.sh \
                 "${TMP_DIR}"/admin/remove-passphase.sh \
                 "${TMP_DIR}"/admin/gen-rsa.sh \
                 "${TMP_DIR}"/admin/"${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE}" \
                 "${TMP_DIR}"/admin/config.inc.php \
                 "${TMP_DIR}"/admin/rsyslog.conf \
                 "${TEMPLATE_DIR}"/common/launch_javaMail.sh \
                 "${TEMPLATE_DIR}"/admin/logrotatehttp
                
echo 'Files uploaded'
                            
# TODO 
# Rotate log files cron job files
# Java mail
# PHPMyAdmin (MySQL remote database administration)
# TODO

#
# Run the install script on the server.
#

echo 'Installing Admin modules ...'

# Set 'ec2-user' and 'root' password, set 'ec2-user' sudo with password.  
# The install script set a password for them.
ssh_run_remote_command 'chmod +x install_admin.sh' \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" 

set +e                
ssh_run_remote_command './install_admin.sh' \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"                          
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then 
   # Clear home directory    
   ssh_run_remote_command 'rm -f -R /home/ec2-user/*' \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}"   
                   
   echo 'Rebooting instance ...'   
   set +e  
   ssh_run_remote_command 'reboot' \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}"
   set -e
else
   echo 'Error running install_admin.sh'
   exit 1
fi
      
## ********** ##
## SSH access ##
## ********** ##

if [[ -z "${adm_sg_id}" ]]
then
   echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group not found"
else
   revoke_access_from_cidr "${adm_sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access' 
fi
       
# Removing temp files
rm -rf "${TMP_DIR:?}"/admin   

echo "Admin box set up completed, IP address: '${eip}'" 
echo
