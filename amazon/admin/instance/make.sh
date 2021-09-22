#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##########################################################################################
# Makes and run an Admin box instance, 
# The instance is built from the Shared 
# Linux hardened image.
# SSH on 38142.
# No root access to the instance.
# The Admin instance is created with an instance profile attached with no role.
# The role is attached to the profile when needed, ex: when installing SSL in the load
# balancer, the Route53role is attached to the profile because the instance has to insert
# a record in the DNS.
# 
# Program installed: 
# rsyslog receiver for all logs; 
# Admin website; 
# Loganalyzer; 
# M/Monit; 
# javaMail;
# phpMyAdmin;
#
##########################################################################################

APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_USER='apache'
PHPMYADMIN_DOCROOT_ID='phpmyadmin.maxmin.it'
PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE='phpmyadmin.http.virtualhost.maxmin.it.conf'
LOGANALYZER_DOCROOT_ID='loganalyzer.maxmin.it'
LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE='loganalyzer.http.virtualhost.maxmin.it.conf'
MONIT_DOCROOT_ID='monit.maxmin.it'
MONIT_HTTP_VIRTUALHOST_CONFIG_FILE='monit.http.virtualhost.maxmin.it.conf'
MMONIT_INSTALL_DIR='/opt/mmonit'
admin_dir='admin'

echo
echo '*********'
echo 'Admin box'
echo '*********'
echo

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${subnet_id}."
fi

get_security_group_id "${DB_INST_SEC_GRP_NM}"
db_sgp_id="${__RESULT}"
  
if [[ -z "${db_sgp_id}" ]]
then
   echo '* ERROR: database security group not found.'
   exit 1
else
   echo "* database security group ID: ${db_sgp_id}."
fi

db_endpoint="$(get_database_endpoint "${DB_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo '* ERROR: database not found.'
   exit 1
else
   echo "* database Endpoint: ${db_endpoint}."
fi

get_image_id "${SHARED_IMG_NM}"
shared_image_id="${__RESULT}"

if [[ -z "${shared_image_id}" ]]
then
   echo '* ERROR: Shared image not found.'
   exit 1
else
   echo "* Shared image ID: ${shared_image_id}."
fi

get_role_id "${AWS_ROUTE53_ROLE_NM}"
role_id="${__RESULT}"

if [[ -z "${role_id}" ]]
then
   echo '* ERROR: Route 53 role not found.'
   exit 1
else
   echo "* Route 53 role ID: ${role_id}."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${admin_dir}"
mkdir "${TMP_DIR}"/"${admin_dir}"

## 
## Security group.
## 

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Admin security group is already created.'
else
   create_security_group "${dtc_id}" "${ADMIN_INST_SEC_GRP_NM}" 'Admin security group.'
   get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"

   echo 'Created Admin security group.'
fi

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e

echo 'Granted SSH access to the Admin box.'
 
##
## Database access.
##

set +e
allow_access_from_security_group "${db_sgp_id}" "${DB_INST_PORT}" 'tcp' "${sgp_id}" > /dev/null 2>&1
set -e
   
echo 'Granted access to the database.'

##
## SSH keys.
##

check_aws_public_key_exists "${ADMIN_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ADMIN_INST_ACCESS_DIR}"
   generate_aws_keypair "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}" 
   
   echo 'SSH private key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

get_public_key "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}"
public_key="${__RESULT}"
   
echo 'SSH public key extracted.'

##
## Cloud init.
##   

## Remove the default user, creates the admin-user user and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${ADMIN_INST_USER_PWD}")"

awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${ADMIN_INST_USER_NM}" -v hostname="${ADMIN_INST_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${TEMPLATE_DIR}"/common/cloud-init/cloud_init_template.yml > "${TMP_DIR}"/"${admin_dir}"/cloud_init.yml
 
echo 
echo 'cloud_init.yml ready.'  

## 
## Admin box. 
## 

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" || \
         'stopped' == "${instance_st}" || \
         'pending' == "${instance_st}" ]] 
   then
      echo "WARN: Admin box already created (${instance_st})."
   else
      echo "ERROR: Admin box already created (${instance_st})."
      exit 1
   fi
else
   echo "Creating the Admin box ..."

   run_instance \
       "${ADMIN_INST_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${ADMIN_INST_PRIVATE_IP}" \
       "${shared_image_id}" \
       "${TMP_DIR}"/"${admin_dir}"/cloud_init.yml
       
   get_instance_id "${ADMIN_INST_NM}"
   instance_id="${__RESULT}"

   echo "Admin box created."
fi

#
# Instance profile.
#

# Applications that run on EC2 instances must sign their API requests with AWS credentials.
# For applications, AWS CLI, and Tools for Windows PowerShell commands that run on the instance, 
# you do not have to explicitly get the temporary security credentials, the AWS SDKs, AWS CLI, and 
# Tools for Windows PowerShell automatically get the credentials from the EC2 instance metadata 
# service and use them. 

check_instance_profile_exists "${ADMIN_INST_PROFILE_NM}"
instance_profile_exists="${__RESULT}"

if [[ 'false' == "${instance_profile_exists}" ]]
then
   create_instance_profile "${ADMIN_INST_PROFILE_NM}" > /dev/null

   echo 'Admin instance profile created.'
else
   echo 'WARN: Admin instance profile already created.'
fi

check_instance_has_instance_profile_associated "${ADMIN_INST_NM}" "${ADMIN_INST_PROFILE_NM}"
is_profile_associated="${__RESULT}"

if [[ 'false' == "${is_profile_associated}" ]]
then
   # Associate the instance profile with the Admin instance. The instance profile doesn't have a role
   # associated, the roles is added when needed, ex: when requesting an SSL certificate for the load
   # balancer or when installing the Bosh director. 
   associate_instance_profile_to_instance "${ADMIN_INST_NM}" "${ADMIN_INST_PROFILE_NM}" > /dev/null 2>&1 && \
   echo 'Instance profile associated to the instance.' ||
   {
      __wait 30
      associate_instance_profile_to_instance "${ADMIN_INST_NM}" "${ADMIN_INST_PROFILE_NM}" > /dev/null 2>&1 && \
      echo 'Instance profile associated to the instance.' ||
      {
         echo 'ERROR: associating the instance profile to the instance.'
         exit 1
      }
   }
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

echo "Admin box public address: ${eip}."

##
## Upload scripts.
## 

echo 'Uploading the scripts to the Admin box ...'

remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
private_key_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 

wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"  

sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_default_http_portSED/${ADMIN_APACHE_DEFAULT_HTTP_PORT}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDmmonit_archiveSED/${MMONIT_ARCHIVE}/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
    -e "s/SEDmonit_http_portSED/${ADMIN_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDmonit_docroot_idSED/${MONIT_DOCROOT_ID}/g" \
    -e "s/SEDmonit_http_virtualhost_fileSED/${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDphpmyadmin_docroot_idSED/${PHPMYADMIN_DOCROOT_ID}/g" \
    -e "s/SEDphpmyadmin_http_virtualhost_fileSED/${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDphpmyadmin_http_portSED/${ADMIN_APACHE_PHPMYADMIN_HTTP_PORT}/g" \
    -e "s/SEDloganalyzer_archiveSED/${LOGANALYZER_ARCHIVE}/g" \
    -e "s/SEDloganalyzer_docroot_idSED/${LOGANALYZER_DOCROOT_ID}/g" \
    -e "s/SEDloganalyzer_http_virtualhost_fileSED/${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDloganalyzer_http_portSED/${ADMIN_APACHE_LOGANALYZER_HTTP_PORT}/g" \
       "${TEMPLATE_DIR}"/admin/install_admin_template.sh > "${TMP_DIR}"/"${admin_dir}"/install_admin.sh

echo 'install_admin.sh ready.'

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/admin/install_admin.sh

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/install_apache_web_server_template.sh > "${TMP_DIR}"/"${admin_dir}"/install_apache_web_server.sh 
 
echo 'install_apache_web_server.sh ready.' 
 
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_FCGI_template.sh > "${TMP_DIR}"/"${admin_dir}"/extend_apache_web_server_with_FCGI.sh    

echo 'extend_apache_web_server_with_FCGI.sh ready.'
 
# Apache Web Server main configuration file.
sed -e "s/SEDapache_default_http_portSED/${ADMIN_APACHE_DEFAULT_HTTP_PORT}/g" \
    -e "s/SEDapache_monit_http_portSED/${ADMIN_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDapache_phpmyadmin_http_portSED/${ADMIN_APACHE_PHPMYADMIN_HTTP_PORT}/g" \
    -e "s/SEDapache_loganalyzer_http_portSED/${ADMIN_APACHE_LOGANALYZER_HTTP_PORT}/g" \
    -e "s/SEDapache_admin_http_portSED/${ADMIN_APACHE_WEBSITE_HTTP_PORT}/g" \
    -e "s/SEDadmin_emailSED/${ADMIN_INST_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_nameSED/${DB_NM}/g" \
    -e "s/SEDdatabase_portSED/${DB_INST_PORT}/g" \
    -e "s/SEDdatabase_user_adminrwSED/${DB_ADMIN_USER_NM}/g" \
    -e "s/SEDdatabase_password_adminrwSED/${DB_ADMIN_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/admin/httpd/httpd_template.conf > "${TMP_DIR}"/"${admin_dir}"/httpd.conf

echo 'httpd.conf ready.'

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/install_apache_web_server.sh \
    "${TMP_DIR}"/"${admin_dir}"/extend_apache_web_server_with_FCGI.sh \
    "${TMP_DIR}"/"${admin_dir}"/httpd.conf \
    "${TEMPLATE_DIR}"/common/httpd/httpd-mpm.conf \
    "${TEMPLATE_DIR}"/common/httpd/09-fcgid.conf \
    "${TEMPLATE_DIR}"/common/httpd/10-fcgid.conf
       
# 'allow_url_fopen = Off' prevent you to access remote files that are opened.
# 'allow_url_include = Off' prevent you to access remote file by require or include statements. 
sed -e "s/SEDallow_url_fopenSED/Off/g" \
    -e "s/SEDallow_url_includeSED/Off/g" \
       "${TEMPLATE_DIR}"/common/php/php.ini > "${TMP_DIR}"/"${admin_dir}"/php.ini

echo 'php.ini ready.'

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TEMPLATE_DIR}"/common/php/install_php.sh \
    "${TMP_DIR}"/"${admin_dir}"/php.ini

# M/Monit systemctl service file
sed -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/admin/mmonit/mmonit_template.service > "${TMP_DIR}"/"${admin_dir}"/mmonit.service 
       
echo 'mmonit.service ready.'
     
# M/Monit website configuration file (only on the Admin server).
sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
    -e "s/SEDserver_admin_private_ipSED/${ADMIN_INST_PRIVATE_IP}/g" \
    -e "s/SEDcollector_portSED/${ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDpublic_portSED/${ADMIN_MMONIT_HTTP_PORT}/g" \
    -e "s/SEDssl_secureSED/false/g" \
    -e "s/SEDcertificateSED//g" \
       "${TEMPLATE_DIR}"/admin/mmonit/server_template.xml > "${TMP_DIR}"/"${admin_dir}"/server.xml
       
echo 'server.xml ready.' 

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${JAR_DIR}"/"${MMONIT_ARCHIVE}" \
    "${TMP_DIR}"/"${admin_dir}"/mmonit.service \
    "${TMP_DIR}"/"${admin_dir}"/server.xml 
 
# Monit demon configuration file (runs on all servers).
sed -e "s/SEDhostnameSED/${ADMIN_INST_NM}/g" \
    -e "s/SEDmmonit_collector_portSED/${ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDapache_monit_portSED/${ADMIN_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDadmin_emailSED/${ADMIN_INST_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/admin/monit/monitrc_template > "${TMP_DIR}"/"${admin_dir}"/monitrc 
       
echo 'monitrc ready.'

# Monit Apache heartbeat virtualhost.           
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '127.0.0.1' \
    "${ADMIN_APACHE_MONIT_HTTP_PORT}" \
    "${ADMIN_INST_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${MONIT_DOCROOT_ID}" 
                   
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'monit' \
    "${APACHE_DOCROOT_DIR}" \
    "${MONIT_DOCROOT_ID}" \
    'monit' 
     
echo "${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE} ready."

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/monitrc \
    "${TMP_DIR}"/"${admin_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" 
       
# Phpmyadmin configuration file.    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    "${TEMPLATE_DIR}"/admin/phpmyadmin/config_inc_template.php > "${TMP_DIR}"/"${admin_dir}"/config.inc.php
    
echo 'config.inc.php ready.'     

# Phpmyadmin Virtual Host file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${ADMIN_APACHE_PHPMYADMIN_HTTP_PORT}" \
    "${ADMIN_INST_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${PHPMYADMIN_DOCROOT_ID}"    
           
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'phpmyadmin' \
    "${APACHE_DOCROOT_DIR}" \
    "${PHPMYADMIN_DOCROOT_ID}" \
    'phpmyadmin'                  

echo "${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE} ready."    

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    "${TMP_DIR}"/"${admin_dir}"/config.inc.php      
     
# Loganalyzer Virtual Host file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${ADMIN_APACHE_LOGANALYZER_HTTP_PORT}" \
    "${ADMIN_INST_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${LOGANALYZER_DOCROOT_ID}"        
     
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'loganalyzer' \
    "${APACHE_DOCROOT_DIR}" \
    "${LOGANALYZER_DOCROOT_ID}" \
    'loganalyzer'   
     
echo "${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE} ready."  

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
     "${JAR_DIR}"/"${LOGANALYZER_ARCHIVE}" \
     "${TMP_DIR}"/"${admin_dir}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" \
     "${TEMPLATE_DIR}"/admin/loganalyzer/config.php 
     
# Rsyslog configuration file.    
sed -e "s/SEDadmin_rsyslog_portSED/${ADMIN_RSYSLOG_PORT}/g" \
    "${TEMPLATE_DIR}"/admin/rsyslog/rsyslog_template.conf > "${TMP_DIR}"/"${admin_dir}"/rsyslog.conf   
    
echo 'rsyslog.conf ready.'

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/rsyslog.conf  \
    "${TEMPLATE_DIR}"/common/launch_javaMail.sh \
    "${TEMPLATE_DIR}"/admin/log/logrotatehttp
    
sed -e "s/SEDssh_portSED/${SHARED_INST_SSH_PORT}/g" \
    -e "s/SEDallowed_userSED/${ADMIN_INST_USER_NM}/g" \
       "${TEMPLATE_DIR}"/common/ssh/sshd_config_template > "${TMP_DIR}"/"${admin_dir}"/sshd_config  
           
scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/sshd_config           

echo 'sshd_config ready.'        
echo 'Scripts uploaded.'
     
# TODO 
# Rotate log files cron job files
# Java mail
# Phpmyadmin (MySQL remote database administration)
# TODO

echo 'Installing the Admin modules ...'

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_admin.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}"

set +e      
ssh_run_remote_command_as_root "${remote_dir}/install_admin.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}"                 
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then
   echo 'Admin box successfully configured.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"     
   
   set +e
   ssh_run_remote_command_as_root "reboot" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"
   set -e
else
   echo 'ERROR: configuring Admin box.'
   exit 1
fi

## 
## SSH Access.
## 

# Revoke SSH access from the development machine

set +e
revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Admin box.' 
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${admin_dir}"  

echo
echo "Admin box up and running at: ${eip}." 

