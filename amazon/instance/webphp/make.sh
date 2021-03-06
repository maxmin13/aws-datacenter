#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Makes a webphp Linux box, from Linux hardened 
# image.
#
# parameters <N> where this is the Nth web box 
# (1-5)
#
# Centralised logging with Rsyslog: each WebPhp
# server sends Apache errors and access logs to
# the Admin server. 
#
# GLOBAL: webphp_id, required
###############################################

APACHE_DOCROOT_DIR='/var/www/html'
APACHE_INSTALL_DIR='/etc/httpd'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_USER='apache'
LBAL_HTTP_VIRTUALHOST_CONFIG_FILE='loadbalancer.http.virtualhost.maxmin.it.conf' 
LBAL_DOCROOT_ID='loadbalancer.maxmin.it'
MONIT_HTTP_VIRTUALHOST_CONFIG_FILE='monit.http.virtualhost.maxmin.it.conf'
MONIT_DOCROOT_ID='monit.maxmin.it'

if [ "$#" -lt 1 ]; then
   echo "USAGE: webphp_id"
   echo "EXAMPLE: 1"
   echo "Only provided $# arguments"
   exit 1
fi

webphp_id="${1}"
export webphp_id="${1}"
   
webphp_nm="${WEBPHP_INST_NM/<ID>/"${webphp_id}"}"
webphp_dir=webphp"${webphp_id}" 
webphp_hostname="${WEBPHP_INST_HOSTNAME/<ID>/"${webphp_id}"}"
webphp_private_ip="${WEBPHP_INST_PRIVATE_IP/<ID>/"${webphp_id}"}"
webphp_sgp_nm="${WEBPHP_INST_SEC_GRP_NM/<ID>/"${webphp_id}"}"
webphp_keypair_nm="${WEBPHP_INST_KEY_PAIR_NM/<ID>/"${webphp_id}"}"
loadbalancer_request_domain="${webphp_hostname}"
monit_request_domain="${webphp_hostname}"

echo
echo '************'
echo "WebPhp box ${webphp_id}" 
echo '************'
echo

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR, data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR, subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${subnet_id}."
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

get_security_group_id "${DB_INST_SEC_GRP_NM}"
db_sgp_id="${__RESULT}"
  
if [[ -z "${db_sgp_id}" ]]
then
   echo '* ERROR: database security group not found' 
   exit 1
else
   echo "* database security group ID: ${db_sgp_id}."
fi

get_database_endpoint "${DB_NM}"
db_endpoint="${__RESULT}"

if [[ -z "${db_endpoint}" ]]
then
   echo '* ERROR: database not found.'
   exit 1
else
   echo "* database endpoint: ${db_endpoint}."
fi

get_instance_id "${ADMIN_INST_NM}"
adm_instance_id="${__RESULT}"

if [[ -z "${adm_instance_id}" ]]
then
   echo '* ERROR: Admin box not found.'
   exit 1
else
   get_instance_state "${ADMIN_INST_NM}"
   adm_instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${adm_instance_id} (${adm_instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
adm_sgp_id="${__RESULT}"

if [[ -z "${adm_sgp_id}" ]]
then
   echo '* ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${adm_sgp_id}."
fi

get_private_ip_address_associated_with_instance "${ADMIN_INST_NM}"
adm_pip="${__RESULT}"

if [[ -z "${adm_pip}" ]]
then
   echo '* ERROR: Admin box private IP address not found.'
   exit 1
else
   echo "* Admin box private IP address: ${adm_pip}."
fi

get_loadbalancer_dns_name "${LBAL_INST_NM}"
loadbalancer_dns_nm="${__RESULT}" 

if [[ -z "${loadbalancer_dns_nm}" ]]
then
   echo '* ERROR: load balancer not found.'
   exit 1
else
   echo "* load balancer: ${loadbalancer_dns_nm}."
fi

get_security_group_id "${LBAL_INST_SEC_GRP_NM}"
lbal_sgp_id="${__RESULT}"

if [[ -z "${lbal_sgp_id}" ]]
then
   echo '* ERROR: load balancer security group not found.'
   exit 1
else
   echo "* load balancer security group ID: ${adm_sgp_id}."
fi

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${TMP_DIR:?}"/"${webphp_dir}"
mkdir "${TMP_DIR}"/"${webphp_dir}"

echo

## 
## Security group 
## 

get_security_group_id "${webphp_sgp_nm}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Webphp security group is already created.'
else
   create_security_group "${dtc_id}" "${webphp_sgp_nm}" "${webphp_sgp_nm}" 
   get_security_group_id "${webphp_sgp_nm}"
   sgp_id="${__RESULT}"
   
   echo 'Created Webphp security group.'
fi

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access to the Webphp box.'

##
## Database access 
##

set +e
allow_access_from_security_group "${db_sgp_id}" "${DB_INST_PORT}" 'tcp' "${sgp_id}" > /dev/null 2>&1
set -e
   
echo 'Granted access to the database.'

## 
## Admin box access
## 

set +e
allow_access_from_security_group "${adm_sgp_id}" "${ADMIN_RSYSLOG_PORT}" 'tcp' "${sgp_id}" > /dev/null 2>&1
set -e
   
echo 'Granted access to Admin Rsyslog.'

set +e
allow_access_from_security_group "${adm_sgp_id}" "${ADMIN_MMONIT_COLLECTOR_PORT}" 'tcp' "${sgp_id}" > /dev/null 2>&1
set -e
   
echo 'Granted access to Admin M/Monit collector.'

##
## SSH keys.
##

check_aws_public_key_exists "${webphp_keypair_nm}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${WEBPHP_INST_ACCESS_DIR}"
   generate_aws_keypair "${webphp_keypair_nm}" "${WEBPHP_INST_ACCESS_DIR}" 
   
   echo 'SSH private key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

get_public_key "${webphp_keypair_nm}" "${WEBPHP_INST_ACCESS_DIR}"
public_key="${__RESULT}"
   
echo 'SSH public key extracted.'

##
## Cloud init
##   

## Removes the default user, creates the webphp-user user and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${WEBPHP_INST_USER_PWD}")" 

awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${WEBPHP_INST_USER_NM}" -v hostname="${webphp_hostname}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${TEMPLATE_DIR}"/common/cloud-init/cloud_init_template.yml > "${TMP_DIR}"/"${webphp_dir}"/cloud_init.yml
 
echo 'cloud_init.yml ready.' 

##
## WebPhp box 
##

get_instance_id "${webphp_nm}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${webphp_nm}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" || \
         'stopped' == "${instance_st}" || \
         'pending' == "${instance_st}" ]]
   then
      echo "WARN: Webphp box already created (${instance_st})."
   else
      echo "ERROR: Webphp box already created (${instance_st})."
      
      exit 1
   fi
else
   echo "Creating the Webphp box ..."

   run_instance \
       "${webphp_nm}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${webphp_private_ip}" \
       "${shared_image_id}" \
       "${TMP_DIR}"/"${webphp_dir}"/cloud_init.yml
       
   get_instance_id "${webphp_nm}"
   instance_id="${__RESULT}"    

   echo "Webphp box created."
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${webphp_nm}"
eip="${__RESULT}"

echo "Webphp box public address: ${eip}."

##
## Upload and install scripts
## 

echo 'Uploading scripts to the Webphp box ...'

remote_dir=/home/"${WEBPHP_INST_USER_NM}"/script
private_key_file="${WEBPHP_INST_ACCESS_DIR}"/"${webphp_keypair_nm}" 

wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${WEBPHP_INST_USER_NM}"  

# Prepare the scripts to run on the server.

sed -e "s/SEDwebphp_inst_user_nmSED/${WEBPHP_INST_USER_NM}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_default_http_portSED/${WEBPHP_APACHE_DEFAULT_HTTP_PORT}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDlbal_http_virtualhost_configSED/${LBAL_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDlbal_docroot_idSED/${LBAL_DOCROOT_ID}/g" \
    -e "s/SEDlbal_http_portSED/${WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT}/g" \
    -e "s/SEDmonit_http_virtualhost_configSED/${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDmonit_http_portSED/${WEBPHP_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDmonit_docroot_idSED/${MONIT_DOCROOT_ID}/g" \
       "${TEMPLATE_DIR}"/webphp/install_webphp_template.sh > "${TMP_DIR}"/"${webphp_dir}"/install_webphp.sh
    
echo 'install_webphp.sh ready.' 

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${webphp_dir}"/install_webphp.sh   
    
# Get the account number.
get_account_number
aws_account="${__RESULT}"

# Make the AES key for PHP sessions (encryption/decryption).
# Its a hex encoded version of $PHP_SESSIONS_PWD
aes1="${PHP_SESSIONS_PWD}"
# Convert to hex
aes2="$(hexdump -e '"%X"' <<< "$aes1")"
# Lowercase
aes3="$(echo "${aes2}" | tr '[:upper:]' '[:lower:]')"
# Only the first 64 characters
aes4="${aes3:0:64}"

# Apache Web Server main configuration file.
sed -e "s/SEDapache_default_http_portSED/${WEBPHP_APACHE_DEFAULT_HTTP_PORT}/g" \
    -e "s/SEDapache_loadbalancer_portSED/${WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT}/g" \
    -e "s/SEDapache_website_portSED/${WEBPHP_APACHE_WEBSITE_HTTP_PORT}/g" \
    -e "s/SEDapache_monit_portSED/${WEBPHP_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDwebphp_emailSED/${WEBPHP_INST_EMAIL}/g" \
    -e "s/SEDdbhostSED/${db_endpoint}/g" \
    -e "s/SEDdbnameSED/${DB_NM}/g" \
    -e "s/SEDdbportSED/${DB_INST_PORT}/g" \
    -e "s/SEDdbuser_webphprwSED/${DB_WEBPHP_USER_NM}/g" \
    -e "s/SEDdbpass_webphprwSED/${DB_WEBPHP_USER_PWD}/g" \
    -e "s/SEDaws_accountSED/${aws_account}/g" \
    -e "s/SEDaws_deployregionSED/${DTC_REGION}/g" \
    -e "s/SEDaeskeySED/${aes4}/g" \
    -e "s/SEDrecaptcha_privatekeySED/${RECAPTCHA_PRIVATE_KEY}/g" \
    -e "s/SEDrecaptcha_publickeySED/${RECAPTCHA_PUBLIC_KEY}/g" \
    -e "s/SEDserveridSED/${webphp_id}/g" \
       "${TEMPLATE_DIR}"/webphp/httpd/httpd_template.conf > "${TMP_DIR}"/"${webphp_dir}"/httpd.conf
       
echo 'httpd.conf ready.'       
       
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/install_apache_web_server_template.sh > \
       "${TMP_DIR}"/"${webphp_dir}"/install_apache_web_server.sh 
 
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_FCGI_template.sh > \
       "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_FCGI.sh 
       
echo 'extend_apache_web_server_with_FCGI.sh ready.' 

# Apache Web Server Security module
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDowasp_archiveSED/${OWASP_ARCHIVE}/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_security_module_template.sh > \
       "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_security_module_template.sh     

echo 'extend_apache_web_server_with_security_module_template.sh ready.'

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${webphp_dir}"/httpd.conf \
    "${TMP_DIR}"/"${webphp_dir}"/install_apache_web_server.sh \
    "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_FCGI.sh  \
    "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_security_module_template.sh \
    "${TEMPLATE_DIR}"/common/httpd/09-fcgid.conf \
    "${TEMPLATE_DIR}"/common/httpd/10-fcgid.conf \
    "${TEMPLATE_DIR}"/common/httpd/httpd-mpm.conf \
    "${TEMPLATE_DIR}"/common/httpd/owasp_mod_security.conf \
    "${TEMPLATE_DIR}"/webphp/httpd/modsecurity_overrides.conf \
    "${JAR_DIR}"/"${OWASP_ARCHIVE}"

# 'allow_url_fopen = On' allows you to access remote files that are opened.
# 'allow_url_include = On' allows you to access remote file by require or include statements. 
sed -e "s/SEDallow_url_fopenSED/On/g" \
    -e "s/SEDallow_url_includeSED/On/g" \
       "${TEMPLATE_DIR}"/common/php/php.ini > "${TMP_DIR}"/"${webphp_dir}"/php.ini

echo 'php.ini ready.'

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}" "${remote_dir}" \
    "${TEMPLATE_DIR}"/common/php/install_php.sh \
    "${TMP_DIR}"/"${webphp_dir}"/php.ini 
  
# Monit demon configuration file (runs on all servers).
sed -e "s/SEDhostnameSED/${webphp_nm}/g" \
    -e "s/SEDserver_admin_private_ipSED/${ADMIN_INST_PRIVATE_IP}/g" \
    -e "s/SEDmmonit_collector_portSED/${ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDapache_http_portSED/${WEBPHP_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDadmin_emailSED/${ADMIN_INST_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/webphp/monit/monitrc_template > "${TMP_DIR}"/"${webphp_dir}"/monitrc        

echo 'monitrc ready.'
    
# Create Monit heartbeat virtualhost to check Apache Web Server.   
create_virtualhost_configuration_file "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}"  \
    '127.0.0.1' \
    "${WEBPHP_APACHE_MONIT_HTTP_PORT}" \
    "${monit_request_domain}" \
    "${APACHE_DOCROOT_DIR}" \
    "${MONIT_DOCROOT_ID}"     
 
# Enable Apache Web Server Monit heartbeat endpoint.                                       
add_alias_to_virtualhost "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'monit' \
    "${APACHE_DOCROOT_DIR}" \
    "${MONIT_DOCROOT_ID}" \
    'monit' 
   
echo "${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE} ready."

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${webphp_dir}"/monitrc \
    "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}"    
       
# Create a load balancer healt-check virtualhost. 
create_virtualhost_configuration_file "${TMP_DIR}"/"${webphp_dir}"/"${LBAL_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT}" \
    "${loadbalancer_request_domain}" \
    "${APACHE_DOCROOT_DIR}" \
    "${LBAL_DOCROOT_ID}"    
 
# Enable the load balancer virtualhost.                                       
add_loadbalancer_rule_to_virtualhost "${TMP_DIR}"/"${webphp_dir}"/"${LBAL_HTTP_VIRTUALHOST_CONFIG_FILE}" \
    'elb.htm' \
    "${APACHE_DOCROOT_DIR}" \
    "${LBAL_DOCROOT_ID}"  

echo "${LBAL_HTTP_VIRTUALHOST_CONFIG_FILE} ready." 

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${webphp_dir}"/"${LBAL_HTTP_VIRTUALHOST_CONFIG_FILE}" 
                
# Rsyslog configuration file.    
sed -e "s/SEDserver_admin_rsyslog_portSED/${ADMIN_RSYSLOG_PORT}/g" \
    -e "s/SEDserver_admin_private_ip_addressSED/${ADMIN_INST_PRIVATE_IP}/g" \
       "${TEMPLATE_DIR}"/webphp/rsyslog/rsyslog_template.conf > "${TMP_DIR}"/"${webphp_dir}"/rsyslog.conf    

echo 'rsyslog.conf ready.'

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${webphp_dir}"/rsyslog.conf
    
sed -e "s/SEDssh_portSED/${SHARED_INST_SSH_PORT}/g" \
    -e "s/SEDallowed_userSED/${WEBPHP_INST_USER_NM}/g" \
       "${TEMPLATE_DIR}"/common/ssh/sshd_config_template > "${TMP_DIR}"/"${webphp_dir}"/sshd_config  
           
scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${WEBPHP_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${webphp_dir}"/sshd_config           

echo 'sshd_config ready.'
echo 'Scripts uploaded.'      
echo 'Installing the Webphp modules ...'

## 
## Remote commands that have to be executed as priviledged user are run with sudo.
## By AWS default, sudo has not password.
## 

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_webphp.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${WEBPHP_INST_USER_NM}" \
    "${WEBPHP_INST_USER_PWD}" 

set +e     
           
ssh_run_remote_command_as_root "${remote_dir}/install_webphp.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${WEBPHP_INST_USER_NM}" \
    "${WEBPHP_INST_USER_PWD}"   
                            
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then
   echo 'Wephp box successfully configured.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${WEBPHP_INST_USER_NM}" \
       "${WEBPHP_INST_USER_PWD}"  
   
   set +e
   ssh_run_remote_command_as_root "reboot" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${WEBPHP_INST_USER_NM}" \
       "${WEBPHP_INST_USER_PWD}"
   set -e
else
   echo 'ERROR: configuring Webphp box.'
   
   exit 1
fi

## 
## Load balancer 
## 

check_instance_is_registered_with_loadbalancer "${LBAL_INST_NM}" "${instance_id}"
is_registered="${__RESULT}"

if [[ 'true' == "${is_registered}" ]]
then
   echo 'WARN: Webphp box already registered with the Load Balancer.'
else
   register_instance_with_loadbalancer "${LBAL_INST_NM}" "${instance_id}"
   
   echo 'Registered Webphp box with the Load Balancer.'
fi

set +e       
allow_access_from_security_group "${sgp_id}" "${WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT}" 'tcp' "${lbal_sgp_id}" > /dev/null 2>&1
set -e
   
echo 'Granted the load balancer access to the webphp instance (healt-check).'

## 
## SSH Access
## 

# Revoke SSH access from the development machine
set +e
revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Webphp box.' 
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"  

echo
echo "Webphp box up and running at: ${eip}." 

