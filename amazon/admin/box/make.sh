#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Makes and run an Admin box instance, 
# The instance is built from the Shared 
# Linux hardened image.
# SSH on 38142.
# No root access to the instance.
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
PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE='phpmyadmin.http.virtualhost.maxmin.it.conf'
LOGANALYZER_DOCROOT_ID='loganalyzer.maxmin.it'
LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE='loganalyzer.http.virtualhost.maxmin.it.conf'
MONIT_DOCROOT_ID='monit.maxmin.it'
MONIT_HTTP_VIRTUALHOST_CONFIG_FILE='monit.http.virtualhost.maxmin.it.conf'
MMONIT_INSTALL_DIR='/opt/mmonit'
admin_dir='admin'

echo '*********'
echo 'Admin box'
echo '*********'
echo

dtc_id="$(get_datacenter_id "${DTC_NM}")"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: Data Center not found.'
   exit 1
else
   echo "* Data Center ID: ${dtc_id}."
fi

subnet_id="$(get_subnet_id "${DTC_SUBNET_MAIN_NM}")"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main Subnet not found.'
   exit 1
else
   echo "* main Subnet ID: ${subnet_id}."
fi

db_sgp_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"
  
if [[ -z "${db_sgp_id}" ]]
then
   echo '* ERROR: database Security Group not found.'
   exit 1
else
   echo "* database Security Group ID: ${db_sgp_id}."
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo '* ERROR: database not found.'
   exit 1
else
   echo "* database Endpoint: ${db_endpoint}."
fi

shared_image_id="$(get_image_id "${SHAR_IMAGE_NM}")"

if [[ -z "${shared_image_id}" ]]
then
   echo '* ERROR: Shared image not found.'
   exit 1
else
   echo "* Shared image ID: ${shared_image_id}."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${admin_dir}"
mkdir "${TMP_DIR}"/"${admin_dir}"

## 
## Security Group 
## 

sgp_id="$(get_security_group_id "${SRV_ADMIN_SEC_GRP_NM}")"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Admin Security Group is already created.'
else
   sgp_id="$(create_security_group "${dtc_id}" "${SRV_ADMIN_SEC_GRP_NM}" 'Admin Security Group')"  

   echo 'Created Admin Security Group.'
fi

granted_ssh="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_ssh}" ]]
then
   echo 'WARN: SSH access to the Admin box already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo 'Granted SSH access to the Admin box.'
fi
 
##
## Database access 
##

granted_db="$(check_access_from_security_group_is_granted "${db_sgp_id}" "${DB_MMDATA_PORT}" "${sgp_id}")"

if [[ -n "${granted_db}" ]]
then
   echo 'WARN: Database access already granted.'
else
   allow_access_from_security_group "${db_sgp_id}" "${DB_MMDATA_PORT}" "${sgp_id}"
   
   echo 'Granted access to the database.'
fi

##
## Cloud init
##   

## Removes the default user, creates the admin-user user and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${SRV_ADMIN_USER_PWD}")" 

key_pair_file="$(get_keypair_file_path "${SRV_ADMIN_KEY_PAIR_NM}" "${SRV_ADMIN_ACCESS_DIR}")"

if [[ -f "${key_pair_file}" ]]
then
   echo 'WARN: SSH key-pair already created.'
else
   # Save the private key file in the access directory
   mkdir -p "${SRV_ADMIN_ACCESS_DIR}"
   generate_keypair "${key_pair_file}" "${SRV_ADMIN_EMAIL}" 
      
   echo 'SSH key-pair created.'
fi

public_key="$(get_public_key "${key_pair_file}")"

awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${SRV_ADMIN_USER_NM}" -v hostname="${SRV_ADMIN_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${TEMPLATE_DIR}"/common/cloud-init/cloud_init_template.yml > "${TMP_DIR}"/"${admin_dir}"/cloud_init.yml
 
echo 
echo 'cloud_init.yml ready.'  

## 
## Admin box 
## 

instance_id="$(get_instance_id "${SRV_ADMIN_NM}")"

if [[ -n "${instance_id}" ]]
then
   instance_state="$(get_instance_state "${SRV_ADMIN_NM}")"
   
   if [[ 'running' == "${instance_state}" || \
         'stopped' == "${instance_state}" || \
         'pending' == "${instance_state}" ]] 
   then
      echo "WARN: Admin box already created (${instance_state})."
   else
      echo "ERROR: Admin box already created (${instance_state})."
      
      exit 1
   fi
else
   echo "Creating the Admin box ..."

   instance_id="$(run_instance \
       "${SRV_ADMIN_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${SRV_ADMIN_PRIVATE_IP}" \
       "${shared_image_id}" \
       "${TMP_DIR}"/"${admin_dir}"/cloud_init.yml)"

   echo "Admin box created."
fi

# Get the public IP address assigned to the instance. 
eip="$(get_public_ip_address_associated_with_instance "${SRV_ADMIN_NM}")"

echo "Admin box public address: ${eip}."

##
## Upload scripts
## 

echo 'Uploading the scripts to the Admin box ...'

remote_dir=/home/"${SRV_ADMIN_USER_NM}"/script

wait_ssh_started "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}"  

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_default_http_portSED/${SRV_ADMIN_APACHE_DEFAULT_HTTP_PORT}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDmmonit_archiveSED/${MMONIT_ARCHIVE}/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
    -e "s/SEDmonit_http_portSED/${SRV_ADMIN_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDmonit_docroot_idSED/${MONIT_DOCROOT_ID}/g" \
    -e "s/SEDmonit_http_virtualhost_fileSED/${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDphpmyadmin_docroot_idSED/${PHPMYADMIN_DOCROOT_ID}/g" \
    -e "s/SEDphpmyadmin_http_virtualhost_fileSED/${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDphpmyadmin_http_portSED/${SRV_ADMIN_APACHE_PHPMYADMIN_HTTP_PORT}/g" \
    -e "s/SEDloganalyzer_archiveSED/${LOGANALYZER_ARCHIVE}/g" \
    -e "s/SEDloganalyzer_docroot_idSED/${LOGANALYZER_DOCROOT_ID}/g" \
    -e "s/SEDloganalyzer_http_virtualhost_fileSED/${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDloganalyzer_http_portSED/${SRV_ADMIN_APACHE_LOGANALYZER_HTTP_PORT}/g" \
       "${TEMPLATE_DIR}"/admin/install_admin_template.sh > "${TMP_DIR}"/"${admin_dir}"/install_admin.sh

echo 'install_admin.sh ready.'

scp_upload_file "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
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
sed -e "s/SEDapache_default_http_portSED/${SRV_ADMIN_APACHE_DEFAULT_HTTP_PORT}/g" \
    -e "s/SEDapache_monit_http_portSED/${SRV_ADMIN_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDapache_phpmyadmin_http_portSED/${SRV_ADMIN_APACHE_PHPMYADMIN_HTTP_PORT}/g" \
    -e "s/SEDapache_loganalyzer_http_portSED/${SRV_ADMIN_APACHE_LOGANALYZER_HTTP_PORT}/g" \
    -e "s/SEDapache_admin_http_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTP_PORT}/g" \
    -e "s/SEDadmin_emailSED/${SRV_ADMIN_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    -e "s/SEDdatabase_portSED/${DB_MMDATA_PORT}/g" \
    -e "s/SEDdatabase_user_adminrwSED/${DB_MMDATA_ADMIN_USER_NM}/g" \
    -e "s/SEDdatabase_password_adminrwSED/${DB_MMDATA_ADMIN_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/admin/httpd/httpd_template.conf > "${TMP_DIR}"/"${admin_dir}"/httpd.conf

echo 'httpd.conf ready.'

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
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

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TEMPLATE_DIR}"/common/php/install_php.sh \
    "${TMP_DIR}"/"${admin_dir}"/php.ini

# M/Monit systemctl service file
sed -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/admin/mmonit/mmonit_template.service > "${TMP_DIR}"/"${admin_dir}"/mmonit.service 
       
echo 'mmonit.service ready.'
     
# M/Monit website configuration file (only on the Admin server).
sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
    -e "s/SEDserver_admin_private_ipSED/${SRV_ADMIN_PRIVATE_IP}/g" \
    -e "s/SEDcollector_portSED/${SRV_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDpublic_portSED/${SRV_ADMIN_MMONIT_HTTP_PORT}/g" \
    -e "s/SEDssl_secureSED/false/g" \
    -e "s/SEDcertificateSED//g" \
       "${TEMPLATE_DIR}"/admin/mmonit/server_template.xml > "${TMP_DIR}"/"${admin_dir}"/server.xml
       
echo 'server.xml ready.' 

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${JAR_DIR}"/"${MMONIT_ARCHIVE}" \
    "${TMP_DIR}"/"${admin_dir}"/mmonit.service \
    "${TMP_DIR}"/"${admin_dir}"/server.xml 
 
# Monit demon configuration file (runs on all servers).
sed -e "s/SEDhostnameSED/${SRV_ADMIN_NM}/g" \
    -e "s/SEDmmonit_collector_portSED/${SRV_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDapache_monit_portSED/${SRV_ADMIN_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDadmin_emailSED/${SRV_ADMIN_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/admin/monit/monitrc_template > "${TMP_DIR}"/"${admin_dir}"/monitrc 
       
echo 'monitrc ready.'

# Monit Apache heartbeat virtualhost.           
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '127.0.0.1' \
    "${SRV_ADMIN_APACHE_MONIT_HTTP_PORT}" \
    "${SRV_ADMIN_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${MONIT_DOCROOT_ID}" 
                   
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'monit' \
    "${APACHE_DOCROOT_DIR}" \
    "${MONIT_DOCROOT_ID}" \
    'monit' 
     
echo "${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE} ready."

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/monitrc \
    "${TMP_DIR}"/"${admin_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" 
       
# Phpmyadmin configuration file.    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    "${TEMPLATE_DIR}"/admin/phpmyadmin/config_inc_template.php > "${TMP_DIR}"/"${admin_dir}"/config.inc.php
    
echo 'config.inc.php ready.'     

# Phpmyadmin Virtual Host file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${SRV_ADMIN_APACHE_PHPMYADMIN_HTTP_PORT}" \
    "${SRV_ADMIN_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${PHPMYADMIN_DOCROOT_ID}"    
           
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'phpmyadmin' \
    "${APACHE_DOCROOT_DIR}" \
    "${PHPMYADMIN_DOCROOT_ID}" \
    'phpmyadmin'                  

echo "${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE} ready."    

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    "${TMP_DIR}"/"${admin_dir}"/config.inc.php      
     
# Loganalyzer Virtual Host file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${admin_dir}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${SRV_ADMIN_APACHE_LOGANALYZER_HTTP_PORT}" \
    "${SRV_ADMIN_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${LOGANALYZER_DOCROOT_ID}"        
     
add_alias_to_virtualhost "${TMP_DIR}"/"${admin_dir}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'loganalyzer' \
    "${APACHE_DOCROOT_DIR}" \
    "${LOGANALYZER_DOCROOT_ID}" \
    'loganalyzer'   
     
echo "${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE} ready."  

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
     "${JAR_DIR}"/"${LOGANALYZER_ARCHIVE}" \
     "${TMP_DIR}"/"${admin_dir}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" \
     "${TEMPLATE_DIR}"/admin/loganalyzer/config.php 
     
# Rsyslog configuration file.    
sed -e "s/SEDadmin_rsyslog_portSED/${SRV_ADMIN_RSYSLOG_PORT}/g" \
    "${TEMPLATE_DIR}"/admin/rsyslog/rsyslog_template.conf > "${TMP_DIR}"/"${admin_dir}"/rsyslog.conf   
    
echo 'rsyslog.conf ready.'

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/rsyslog.conf  \
    "${TEMPLATE_DIR}"/common/launch_javaMail.sh \
    "${TEMPLATE_DIR}"/admin/log/logrotatehttp
    
sed -e "s/SEDssh_portSED/${SHAR_INSTANCE_SSH_PORT}/g" \
    -e "s/SEDallowed_userSED/${SRV_ADMIN_USER_NM}/g" \
       "${TEMPLATE_DIR}"/common/ssh/sshd_config_template > "${TMP_DIR}"/"${admin_dir}"/sshd_config  
           
scp_upload_file "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${admin_dir}"/sshd_config           

echo 'sshd_config ready.'        
echo 'Scripts uploaded.'
     
# TODO 
# Rotate log files cron job files
# Java mail
# Phpmyadmin (MySQL remote Database administration)
# TODO

echo 'Installing the Admin modules ...'

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_admin.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}" \
    "${SRV_ADMIN_USER_PWD}"

set +e   
          
ssh_run_remote_command_as_root "${remote_dir}/install_admin.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}" \
    "${SRV_ADMIN_USER_PWD}"   
                     
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then
   echo 'Admin box successfully configured.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}"     
   
   set +e
   ssh_run_remote_command_as_root "reboot" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}" \
       "${SRV_ADMIN_USER_PWD}"
   set -e
else
   echo 'ERROR: configuring Admin box.'
   exit 1
fi
      
## 
## SSH Access.
## 

granted_ssh="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_ssh}" ]]
then
   # Revoke SSH access from the development machine
   revoke_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo 'Revoked SSH access to the Admin box.' 
fi
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${admin_dir}"  

echo
echo "Admin box up and running at: ${eip}." 
echo
