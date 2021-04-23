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

APACHE_DOC_ROOT_DIR='/var/www/html'
MMONIT_INSTALL_DIR='/opt/mmonit'
APACHE_INSTALL_DIR='/etc/httpd'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_JAIL_DIR='/jail'
# Development key and cert
SERVER_ADMIN_KEY_FILE_NM='admin.maxmin.it.key'
SERVER_ADMIN_CRT_FILE_NM='admin.maxmin.it.crt'
SERVER_ADMIN_CRT_CHAIN_FILE_NM='admin.maxmin.it.chain.crt'

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
rm -rf "${TMP_DIR}"/admin
mkdir "${TMP_DIR}"/admin

## ************ ##
## SSH Key Pair ##
## ************ ##

# Delete the local private-key and the remote public-key.
delete_key_pair "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_CREDENTIALS_DIR}"

# Create a key pair to SSH into the instance.
create_key_pair "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_CREDENTIALS_DIR}"
echo 'Created Admin Key Pair to SSH into the Instance, the Private Key is saved in the credentials directory'

private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_CREDENTIALS_DIR}")"

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
echo 'Authorized Database access from the Admin box'

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

# Prepare the scripts to run on the server.

sed -e "s/SEDapache_doc_root_dirSED/$(escape ${APACHE_DOC_ROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDserver_admin_hostnameSED/${SERVER_ADMIN_HOSTNAME}/g" \
    -e "s/SEDmmonit_archiveSED/${MMONIT_ARCHIVE}/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
    -e "s/SEDlog_analyzer_archiveSED/${LOGANALYZER_ARCHIVE}/g" \
    -e "s/SEDphpmyadmin_domain_nameSED/${SERVER_ADMIN_PHPMYADMIN_DOMAIN_NM}/g" \
    -e "s/SEDloganalyzer_domain_nameSED/${SERVER_ADMIN_LOGANALYZER_DOMAIN_NM}/g" \
    -e "s/SEDmonit_domain_nameSED/${SERVER_ADMIN_MONIT_HEARTBEAT_DOMAIN_NM}/g" \
       "${TEMPLATE_DIR}"/admin/install_admin_template.sh > "${TMP_DIR}"/admin/install_admin.sh

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/apache/g" \
    -e "s/SEDapache_doc_root_dirSED/$(escape ${APACHE_DOC_ROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDapache_jail_dirSED/$(escape ${APACHE_JAIL_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/install_apache_web_server_template.sh > "${TMP_DIR}"/admin/install_apache_web_server.sh 
 
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_FCGI_template.sh > "${TMP_DIR}"/admin/extend_apache_web_server_with_FCGI.sh    
    
# Apache Web Server main configuration file.
# The system host name is modified during the installation and set equal to 'admin.maxmin.it' DNS domain (install_admin.sh script). 
# The ServerName directive in the main server and in the virtual host configuration (httpd.conf and ssl.conf) must be set to the same value.
sed -e "s/SEDserver_admin_hostnameSED/${SERVER_ADMIN_HOSTNAME}/g" \
    -e "s/SEDapache_http_portSED/${SERVER_ADMIN_APACHE_HTTP_PORT}/g" \
    -e "s/SEDadmin_emailSED/${SERVER_ADMIN_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_doc_root_dirSED/$(escape ${APACHE_DOC_ROOT_DIR})/g" \
    -e "s/SEDapache_usrSED/apache/g" \
    -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    -e "s/SEDdatabase_portSED/${DB_MMDATA_PORT}/g" \
    -e "s/SEDdatabase_user_adminrwSED/${DB_MMDATA_ADMIN_USER_NM}/g" \
    -e "s/SEDdatabase_password_adminrwSED/${DB_MMDATA_ADMIN_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/admin/httpd/httpd_template.conf > "${TMP_DIR}"/admin/httpd.conf
      
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       -e "s/SEDenvironmentSED/${ENV}/g" \
       -e "s/SEDapache_usrSED/apache/g" \
       "${TEMPLATE_DIR}"/common/httpd/install_apache_web_server_ssl_template.sh > "${TMP_DIR}"/admin/install_apache_web_server_ssl.sh       

if [[ 'development' == "${ENV}" ]]
then
   # Apache Web Server SSL key generation script.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDkey_pwdSED/${SERVER_ADMIN_PRIV_KEY_PWD}/g" \
          "${TEMPLATE_DIR}"/ssl/gen-rsa_template.exp > "${TMP_DIR}"/admin/gen-rsa.sh
 
   # Apache Web Server remove the password protection from the key script.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDnew_key_fileSED/server.key.org/g" \
       -e "s/SEDkey_pwdSED/${SERVER_ADMIN_PRIV_KEY_PWD}/g" \
          "${TEMPLATE_DIR}"/ssl/remove-passphase_template.exp > "${TMP_DIR}"/admin/remove-passphase.sh   

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

   # Apache Web Server SSL configuration file.
   sed -e "s/SEDapache_https_portSED/${SERVER_ADMIN_APACHE_HTTPS_PORT}/g" \
       -e "s/SEDssl_certificate_key_fileSED/server.key/g" \
       -e "s/SEDssl_certificate_fileSED/server.crt/g" \
          "${TEMPLATE_DIR}"/common/httpd/ssl_template.conf > "${TMP_DIR}"/admin/ssl.conf 
                   
elif [[ 'production' == "${ENV}" ]]
then
   # TODO Create a certificate authenticated by a Certificate Authority.
   # TODO
   # TODO
   echo 'Error: production configuration missing'
   exit 1
   
   # Apache Web Server SSL configuration file.
   sed -e "s/SEDapache_https_portSED/${SERVER_ADMIN_APACHE_HTTPS_PORT}/g" \
       -e "s/SEDssl_certificate_key_fileSED/${SERVER_ADMIN_KEY_FILE_NM}/g" \
       -e "s/SEDssl_certificate_fileSED/${SERVER_ADMIN_CRT_FILE_NM}/g" \
       -e "s/SEDssl_certificate_chain_fileSED/${SERVER_ADMIN_CRT_CHAIN_FILE_NM}/g" \
          "${TEMPLATE_DIR}"/common/httpd/ssl_template.conf > "${TMP_DIR}"/admin/ssl.conf
          
   sudo awk -i inplace '{if($1 == "#SSLCertificateChainFile"){$1="SSLCertificateChainFile"; print $0} else {print $0}}' "${TMP_DIR}"/admin/ssl.conf       
fi

# Script that sets a password for 'ec2-user' user.
sed -e "s/SEDuser_nameSED/ec2-user/g" \
    -e "s/SEDuser_pwdSED/${SERVER_ADMIN_EC2_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/users/chp_user_template.exp > "${TMP_DIR}"/admin/chp_ec2-user.sh

# Script that sets a password for 'root' user.
sed -e "s/SEDuser_nameSED/root/g" \
    -e "s/SEDuser_pwdSED/${SERVER_ADMIN_ROOT_PWD}/g" \
       "${TEMPLATE_DIR}"/users/chp_user_template.exp > "${TMP_DIR}"/admin/chp_root.sh

# M/Monit systemctl service file
sed -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/admin/mmonit/mmonit_template.service > "${TMP_DIR}"/admin/mmonit.service 
     
# M/Monit website configuration file (only on the Admin server).
sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
    -e "s/SEDserver_admin_private_ipSED/${SERVER_ADMIN_PRIVATE_IP}/g" \
    -e "s/SEDmmonit_http_portSED/${SERVER_ADMIN_MMONIT_HTTP_PORT}/g" \
    -e "s/SEDmmonit_https_portSED/${SERVER_ADMIN_MMONIT_HTTPS_PORT}/g" \
       "${TEMPLATE_DIR}"/admin/mmonit/server_template.xml > "${TMP_DIR}"/admin/server.xml

# Monit demon configuration file (runs on all servers).
sed -e "s/SEDhostnameSED/${SERVER_ADMIN_NM}/g" \
    -e "s/SEDmmonit_collector_portSED/${SERVER_ADMIN_MMONIT_HTTP_PORT}/g" \
    -e "s/SEDapache_http_portSED/${SERVER_ADMIN_APACHE_HTTP_PORT}/g" \
    -e "s/SEDadmin_emailSED/${SERVER_ADMIN_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/admin/monitrc_template > "${TMP_DIR}"/admin/monitrc   
       
# Create Apache Web Server Monit heartbeat virtualhost.   
create_virtual_host_configuration_file '127.0.0.1' \
                                       "${SERVER_ADMIN_APACHE_HTTP_PORT}" \
                                       "${SERVER_ADMIN_HOSTNAME}" \
                                       "${TMP_DIR}"/admin/monit.virtualhost.maxmin.it.conf
 
# Enable Apache Web Server Monit heartbeat endpoint.                                       
add_alias_to_virtual_host 'monit' \
                            "${APACHE_DOC_ROOT_DIR}" \
                            "${SERVER_ADMIN_MONIT_HEARTBEAT_DOMAIN_NM}" \
                            "${TMP_DIR}"/admin/monit.virtualhost.maxmin.it.conf 
                            
# PhpMyAdmin configuration file.    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
       "${TEMPLATE_DIR}"/admin/config_inc_template.php > "${TMP_DIR}"/admin/config.inc.php

# Apache Web Server Virtual Host file.
create_virtual_host_configuration_file '*' \
                                       "${SERVER_ADMIN_APACHE_HTTPS_PORT}" \
                                       "${SERVER_ADMIN_HOSTNAME}" \
                                       "${TMP_DIR}"/admin/public.virtualhost.maxmin.it.conf
  
# Enable phpmyadmin site.                                     
add_alias_to_virtual_host 'phpmyadmin' \
                            "${APACHE_DOC_ROOT_DIR}" \
                            "${SERVER_ADMIN_PHPMYADMIN_DOMAIN_NM}" \
                            "${TMP_DIR}"/admin/public.virtualhost.maxmin.it.conf 
                            
# Enable Loganalyzer site.
add_alias_to_virtual_host 'loganalyzer' \
                            "${APACHE_DOC_ROOT_DIR}" \
                            "${SERVER_ADMIN_LOGANALYZER_DOMAIN_NM}" \
                            "${TMP_DIR}"/admin/public.virtualhost.maxmin.it.conf 
                            
# Rsyslog configuration file.    
sed -e "s/SEDadmin_rsyslog_portSED/${SERVER_ADMIN_RSYSLOG_PORT}/g" \
       "${TEMPLATE_DIR}"/admin/rsyslog_template.conf > "${TMP_DIR}"/admin/rsyslog.conf    
  
echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

echo 'Uploading files ...'
scp_upload_files "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
                 "${JAR_DIR}"/"${LOGANALYZER_ARCHIVE}" \
                 "${JAR_DIR}"/"${MMONIT_ARCHIVE}" \
                 "${TEMPLATE_DIR}"/common/launch_javaMail.sh \
                 "${TEMPLATE_DIR}"/common/php/php.ini \
                 "${TEMPLATE_DIR}"/common/php/install_php.sh \
                 "${TEMPLATE_DIR}"/common/httpd/httpd-mpm.conf \
                 "${TEMPLATE_DIR}"/common/httpd/00-ssl.conf \
                 "${TEMPLATE_DIR}"/common/httpd/09-fcgid.conf \
                 "${TEMPLATE_DIR}"/common/httpd/10-fcgid.conf \
                 "${TEMPLATE_DIR}"/admin/config.php \
                 "${TMP_DIR}"/admin/ssl.conf \
                 "${TMP_DIR}"/admin/httpd.conf \
                 "${TMP_DIR}"/admin/install_admin.sh \
                 "${TMP_DIR}"/admin/install_apache_web_server.sh \
                 "${TMP_DIR}"/admin/extend_apache_web_server_with_FCGI.sh \
                 "${TMP_DIR}"/admin/install_apache_web_server_ssl.sh \
                 "${TMP_DIR}"/admin/chp_root.sh \
                 "${TMP_DIR}"/admin/chp_ec2-user.sh \
                 "${TMP_DIR}"/admin/gen-selfsign-cert.sh \
                 "${TMP_DIR}"/admin/remove-passphase.sh \
                 "${TMP_DIR}"/admin/gen-rsa.sh \
                 "${TMP_DIR}"/admin/public.virtualhost.maxmin.it.conf \
                 "${TMP_DIR}"/admin/monit.virtualhost.maxmin.it.conf \
                 "${TMP_DIR}"/admin/config.inc.php \
                 "${TMP_DIR}"/admin/rsyslog.conf \
                 "${TMP_DIR}"/admin/monitrc \
                 "${TMP_DIR}"/admin/mmonit.service \
                 "${TMP_DIR}"/admin/server.xml \
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
rm -rf "${TMP_DIR}"/admin   

echo "Admin box set up completed, IP address: '${eip}'" 
echo
