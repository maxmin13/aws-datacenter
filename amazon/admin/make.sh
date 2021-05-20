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
echo 'Admin box'
echo '*********'
echo

admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"

if [[ -n "${admin_instance_id}" ]]
then
   echo '* ERROR: the admin box was already created'
   exit 1
fi

vpc_id="$(get_vpc_id "${VPC_NM}")"
  
if [[ -z "${vpc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: '${vpc_id}'"
fi

subnet_id="$(get_subnet_id "${SUBNET_MAIN_NM}")"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: '${subnet_id}'"
fi

db_sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"
  
if [[ -z "${db_sg_id}" ]]
then
   echo '* ERROR: database security group not found'
   exit 1
else
   echo "* database security group ID: ${db_sg_id}"
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo '* ERROR: database not found'
   exit 1
else
   echo "* database Endpoint: ${db_endpoint}"
fi

shared_base_ami_id="$(get_image_id "${SHARED_BASE_AMI_NM}")"

if [[ -z "${shared_base_ami_id}" ]]
then
   echo '* ERROR: shared base image not found'
   exit 1
else
   echo "* shared base image ID: ${shared_base_ami_id}"
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/admin
mkdir "${TMP_DIR}"/admin

## 
## SSH key pair 
## 

# Create a key pair to SSH into the instance.
create_key_pair "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}"
echo 'Created admin key pair to SSH into the Instance, the private key is saved in the credentials directory'

private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}")"

## 
## Security group 
## 

my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
adm_sg_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -n "${adm_sg_id}" ]]
then
   echo 'ERROR: the admin security group is already created'
   exit 1
fi
  
adm_sg_id="$(create_security_group "${vpc_id}" "${SERVER_ADMIN_SEC_GRP_NM}" \
                    'Admin security group')"

allow_access_from_cidr "${adm_sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
#####allow_access_from_cidr "${adm_sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
echo 'Created admin security group'

##
## Database access 
##

allow_access_from_security_group "${db_sg_id}" "${DB_MMDATA_PORT}" "${adm_sg_id}"
echo 'Granted access to the database'

## 
## Admin instance 
## 

echo 'Creating the admin instance ...'
# The Admin instance is run from the secured Shared Image.
run_admin_instance "${shared_base_ami_id}" "${adm_sg_id}" "${subnet_id}"
admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"
echo 'Admin instance created'

## 
## Public IP 
## 

echo 'Checking for any public IP avaiable in the account'
eip="$(get_public_ip_address_unused)"

if [[ -n "${eip}" ]]
then
   echo "Found the '${eip}' unused public IP address"
else
   echo 'Not found any unused public IP address, a new one must be allocated'
   eip="$(allocate_public_ip_address)" 
   echo "The '${eip}' public IP address has been allocated to the account"
fi

associate_public_ip_address_to_instance "${eip}" "${admin_instance_id}"
echo "The '${eip}' public IP address has been associated with the Admin instance"

##
## Modules 
## 

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
       "${TEMPLATE_DIR}"/"${webphp_dir}"/install_admin_template.sh > "${TMP_DIR}"/"${webphp_dir}"/install_admin.sh

echo 'install_admin.sh ready'

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/install_apache_web_server_template.sh > "${TMP_DIR}"/"${webphp_dir}"/install_apache_web_server.sh 
 
echo 'install_apache_web_server.sh ready' 
 
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_FCGI_template.sh > "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_FCGI.sh    

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
       "${TEMPLATE_DIR}"/"${webphp_dir}"/httpd/httpd_template.conf > "${TMP_DIR}"/"${webphp_dir}"/httpd.conf

echo 'Apache httpd.conf ready'
   
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_SSL_module_template.sh > "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_SSL_module_template.sh       

echo 'extend_apache_web_server_with_SSL_module_template.sh ready'

# 'allow_url_fopen = Off' prevent you to access remote files that are opened.
# 'allow_url_include = Off' prevent you to access remote file by require or include statements. 
sed -e "s/SEDallow_url_fopenSED/Off/g" \
    -e "s/SEDallow_url_includeSED/Off/g" \
       "${TEMPLATE_DIR}"/common/php/php.ini > "${TMP_DIR}"/"${webphp_dir}"/php.ini

echo 'php.ini ready'

#if [[ 'development' == "${ENV}" ]]
if 'true'
then
   # Apache Web Server SSL key generation script.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDkey_pwdSED/${SERVER_ADMIN_PRIV_KEY_PWD}/g" \
          "${TEMPLATE_DIR}"/ssl/gen-rsa_template.exp > "${TMP_DIR}"/"${webphp_dir}"/gen-rsa.sh

   echo 'Apache SSL gen-rsa.sh ready'

   # Apache Web Server remove the password protection from the key script.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDnew_key_fileSED/server.key.org/g" \
       -e "s/SEDkey_pwdSED/${SERVER_ADMIN_PRIV_KEY_PWD}/g" \
          "${TEMPLATE_DIR}"/ssl/remove-passphase_template.exp > "${TMP_DIR}"/"${webphp_dir}"/remove-passphase.sh   

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
          "${TEMPLATE_DIR}"/ssl/gen-selfsign-cert_template.exp > "${TMP_DIR}"/"${webphp_dir}"/gen-selfsign-cert.sh

   echo 'gen-selfsign-cert.sh ready'
   
   # Apache Web Server SSL configuration file.
   sed -e "s/SEDwebsite_portSED/${SERVER_ADMIN_APACHE_WEBSITE_PORT}/g" \
       -e "s/SEDphpmyadmin_portSED/${SERVER_ADMIN_APACHE_PHPMYADMIN_PORT}/g" \
       -e "s/SEDloganalyzer_portSED/${SERVER_ADMIN_APACHE_LOGANALYZER_PORT}/g" \
       -e "s/SEDssl_certificate_key_fileSED/server.key/g" \
       -e "s/SEDssl_certificate_fileSED/server.crt/g" \
          "${TEMPLATE_DIR}"/"${webphp_dir}"/httpd/ssl_template.conf > "${TMP_DIR}"/"${webphp_dir}"/ssl.conf 
          
   echo 'Apache ssl.conf ready'
                   
#elif [[ 'production' == "${ENV}" ]]
#then
else
   # TODO
   # TODO Use a certificate authenticated by a Certificate Authority.
   # TODO Enable SSLCertificateChainFile in ssl.conf
   # TODO        
   # TODO  sudo awk -i inplace '{if($1 == "#SSLCertificateChainFile"){$1="SSLCertificateChainFile"; print $0} else {print $0}}' "${TMP_DIR}"/"${webphp_dir}"/ssl.conf 
   
   echo 'ERROR: a production certificate is not available, use a developement self-signed one'
   exit 1        
fi

# Script that sets a password for 'ec2-user' user.
sed -e "s/SEDuser_nameSED/ec2-user/g" \
    -e "s/SEDuser_pwdSED/${SERVER_ADMIN_EC2_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/users/chp_user_template.exp > "${TMP_DIR}"/"${webphp_dir}"/chp_ec2-user.sh
  
echo 'Change ec2-user password chp_ec2-user.sh ready'

# M/Monit systemctl service file
sed -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/"${webphp_dir}"/mmonit/mmonit_template.service > "${TMP_DIR}"/"${webphp_dir}"/mmonit.service 
       
echo 'M/Monit mmonit.service ready'
     
# M/Monit website configuration file (only on the Admin server).
sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
    -e "s/SEDserver_admin_private_ipSED/${SERVER_ADMIN_PRIVATE_IP}/g" \
    -e "s/SEDcollector_portSED/${SERVER_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDpublic_portSED/${SERVER_ADMIN_MMONIT_PUBLIC_PORT}/g" \
       "${TEMPLATE_DIR}"/"${webphp_dir}"/mmonit/server_template.xml > "${TMP_DIR}"/"${webphp_dir}"/server.xml
       
echo 'M/Monit server.xml ready'  

# Monit demon configuration file (runs on all servers).
sed -e "s/SEDhostnameSED/${SERVER_ADMIN_NM}/g" \
    -e "s/SEDmmonit_collector_portSED/${SERVER_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDapache_monit_portSED/${SERVER_ADMIN_APACHE_MONIT_PORT}/g" \
    -e "s/SEDadmin_emailSED/${SERVER_ADMIN_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/"${webphp_dir}"/monitrc_template > "${TMP_DIR}"/"${webphp_dir}"/monitrc 
       
echo 'Monit monitrc ready'  

# PhpMyAdmin configuration file.    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
       "${TEMPLATE_DIR}"/"${webphp_dir}"/config_inc_template.php > "${TMP_DIR}"/"${webphp_dir}"/config.inc.php
       
echo 'PhpMyAdmin config.inc.php ready'
                            
# Rsyslog configuration file.    
sed -e "s/SEDadmin_rsyslog_portSED/${SERVER_ADMIN_RSYSLOG_PORT}/g" \
       "${TEMPLATE_DIR}"/"${webphp_dir}"/rsyslog_template.conf > "${TMP_DIR}"/"${webphp_dir}"/rsyslog.conf   
       
echo 'Rsyslog rsyslog.conf ready'
       
# Monit Apache heartbeat virtualhost.                                     
create_virtualhost_configuration_file '127.0.0.1' \
                           "${SERVER_ADMIN_APACHE_MONIT_PORT}" \
                           "${SERVER_ADMIN_HOSTNAME}" \
                           "${APACHE_DOCROOT_DIR}" \
                           "${MONIT_DOCROOT_ID}" \
                           "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}"                                      
                                       
add_alias_to_virtualhost 'monit' \
                           "${APACHE_DOCROOT_DIR}" \
                           "${MONIT_DOCROOT_ID}" \
                           "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}"
                            
echo "Monit ${MONIT_VIRTUALHOST_CONFIG_FILE} ready"                                                                                        

# phpmyadmin Virtual Host file.
create_virtualhost_configuration_file '*' \
                           "${SERVER_ADMIN_APACHE_PHPMYADMIN_PORT}" \
                           "${SERVER_ADMIN_HOSTNAME}" \
                           "${APACHE_DOCROOT_DIR}" \
                           "${PHPMYADMIN_DOCROOT_ID}" \
                           "${TMP_DIR}"/"${webphp_dir}"/"${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE}"      
                                     
add_alias_to_virtualhost 'phpmyadmin' \
                           "${APACHE_DOCROOT_DIR}" \
                           "${PHPMYADMIN_DOCROOT_ID}" \
                           "${TMP_DIR}"/"${webphp_dir}"/"${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE}"                       

echo "PhpMyAdmin ${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE} ready"                             
                            
# loganalyzer Virtual Host file.
create_virtualhost_configuration_file '*' \
                           "${SERVER_ADMIN_APACHE_LOGANALYZER_PORT}" \
                           "${SERVER_ADMIN_HOSTNAME}" \
                           "${APACHE_DOCROOT_DIR}" \
                           "${LOGANALYZER_DOCROOT_ID}" \
                           "${TMP_DIR}"/"${webphp_dir}"/"${LOGANALYZER_VIRTUALHOST_CONFIG_FILE}"                              
                            
add_alias_to_virtualhost 'loganalyzer' \
                           "${APACHE_DOCROOT_DIR}" \
                           "${LOGANALYZER_DOCROOT_ID}" \
                           "${TMP_DIR}"/"${webphp_dir}"/"${LOGANALYZER_VIRTUALHOST_CONFIG_FILE}"  
                            
echo "Loganalyzer ${LOGANALYZER_VIRTUALHOST_CONFIG_FILE} ready"                                    
  
echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"


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
                           "${TEMPLATE_DIR}"/common/php/install_php.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/php.ini \
                           "${TMP_DIR}"/"${webphp_dir}"/install_admin.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/install_apache_web_server.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_FCGI.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_SSL_module_template.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/ssl.conf \
                           "${TMP_DIR}"/"${webphp_dir}"/httpd.conf \
                           "${TEMPLATE_DIR}"/common/httpd/httpd-mpm.conf \
                           "${TEMPLATE_DIR}"/common/httpd/00-ssl.conf \
                           "${TEMPLATE_DIR}"/common/httpd/09-fcgid.conf \
                           "${TEMPLATE_DIR}"/common/httpd/10-fcgid.conf \
                           "${JAR_DIR}"/"${LOGANALYZER_ARCHIVE}" \
                           "${TMP_DIR}"/"${webphp_dir}"/"${LOGANALYZER_VIRTUALHOST_CONFIG_FILE}" \
                           "${TEMPLATE_DIR}"/"${webphp_dir}"/config.php \
                           "${JAR_DIR}"/"${MMONIT_ARCHIVE}" \
                           "${TMP_DIR}"/"${webphp_dir}"/monitrc \
                           "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}" \
                           "${TMP_DIR}"/"${webphp_dir}"/mmonit.service \
                           "${TMP_DIR}"/"${webphp_dir}"/server.xml \
                           "${TMP_DIR}"/"${webphp_dir}"/chp_ec2-user.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/gen-selfsign-cert.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/remove-passphase.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/gen-rsa.sh \
                           "${TMP_DIR}"/"${webphp_dir}"/"${PHPMYADMIN_VIRTUALHOST_CONFIG_FILE}" \
                           "${TMP_DIR}"/"${webphp_dir}"/config.inc.php \
                           "${TMP_DIR}"/"${webphp_dir}"/rsyslog.conf \
                           "${TEMPLATE_DIR}"/common/launch_javaMail.sh \
                           "${TEMPLATE_DIR}"/"${webphp_dir}"/logrotatehttp
                
echo 'Scripts uploaded'
                            
# TODO 
# Rotate log files cron job files
# Java mail
# PHPMyAdmin (MySQL remote database administration)
# TODO

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
      
## 
## SSH access 
## 

if [[ -n "${adm_sg_id}" ]]
then
   ##### revoke_access_from_cidr "${adm_sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   revoke_access_from_cidr "${adm_sg_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
   echo 'Revoked SSH access to the admin instance' 
fi
       
# Removing temp files
rm -rf "${TMP_DIR:?}"/admin   

echo "Admin box up and running at: '${eip}'" 
echo
