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
LOADBALANCER_VIRTUALHOST_CONFIG_FILE='loadbalancer.virtualhost.maxmin.it.conf' 
LOADBALANCER_DOCROOT_ID='loadbalancer.maxmin.it'
MONIT_VIRTUALHOST_CONFIG_FILE='monit.virtualhost.maxmin.it.conf'
MONIT_DOCROOT_ID='monit.maxmin.it'

echo '**********'
echo 'WebPhp box'
echo '**********'
echo

if [[ $# -lt 1 ]]
then
   echo 'Error: Missing mandatory arguments'
   exit 1
else
   export webphp_id="${1}"
   webphp_nm="${SERVER_WEBPHP_NM/<ID>/"${webphp_id}"}"
   webphp_hostname="${SERVER_WEBPHP_HOSTNAME/<ID>/"${webphp_id}"}"
   webphp_sgp_nm="${SERVER_WEBPHP_SEC_GRP_NM/<ID>/"${webphp_id}"}"
   webphp_db_user_nm="${DB_MMDATA_WEBPHP_USER_NM}"
   webphp_dir=webphp"${webphp_id}"   
   loadbalancer_request_domain="${webphp_hostname}"
   monit_request_domain="${webphp_hostname}"
   key_pair_nm="${SERVER_WEBPHP_KEY_PAIR_NM/<ID>/"${webphp_id}"}"
fi

webphp_instance_id="$(get_instance_id "${webphp_nm}")"

if [[ -n "${webphp_instance_id}" ]]
then
   echo "Error: Instance '${webphp_nm}' already created"
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

shared_base_ami_id="$(get_image_id "${SHARED_BASE_AMI_NM}")"

if [[ -z "${shared_base_ami_id}" ]]
then
   echo "Error: Shared Base Image '${SHARED_BASE_AMI_NM}' not found"
   exit 1
else
   echo "* Shared Base Image ID: ${shared_base_ami_id}"
fi

db_sgp_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"
  
if [[ -z "${db_sgp_id}" ]]
then
   echo "ERROR: The '${DB_MMDATA_SEC_GRP_NM}' Database Security Group not found"
   exit 1
else
   echo "* Database Security Group ID: ${db_sgp_id}"
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo "Error: Database '${DB_MMDATA_NM}' Endpoint not found"
   exit 1
else
   echo "* Database Endpoint: ${db_endpoint}"
fi

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
   echo 'ERROR: Admin security group not found'
   exit 1
else
   echo "* Admin Security Group ID: '${adm_sgp_id}'"
fi

adm_pip="$(get_private_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${adm_pip}" ]]
then
   echo 'ERROR: Admin private IP address not found'
   exit 1
else
   echo "* Admin private IP address: '${adm_pip}'"
fi

loadbalancer_dns_nm="$(get_loadbalancer_dns_name "${LBAL_NM}")"
if [[ -z "${loadbalancer_dns_nm}" ]]
then
   echo 'ERROR: Load Balancer not found'
   exit 1
else
   echo "* Load Balancer: '${loadbalancer_dns_nm}'"
fi

loadbalancer_sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -z "${loadbalancer_sgp_id}" ]]
then
   echo 'ERROR: Load Balancer security group not found'
   exit 1
else
   echo "* Load Balancer Group ID: '${adm_sgp_id}'"
fi

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${TMP_DIR:?}"/"${webphp_dir}"
mkdir "${TMP_DIR}"/"${webphp_dir}"

echo

echo "Creating WebPhp box: ${webphp_nm} ..."

## *** ##
## SSH ##
## *** ##

# Delete the local private-key and the remote public-key.
delete_key_pair "${key_pair_nm}" "${WEBPHP_CREDENTIALS_DIR}"

# Create a key pair to SSH into the instance.
create_key_pair "${key_pair_nm}" "${WEBPHP_CREDENTIALS_DIR}"
echo 'Created WebPhp Key Pair to SSH into the Instance, the Private Key is saved in the credentials directory'

private_key="$(get_private_key_path "${key_pair_nm}" "${WEBPHP_CREDENTIALS_DIR}")"

## ************** ##
## Security Group ##
## ************** ##

my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
webphp_sgp_id="$(get_security_group_id "${webphp_sgp_nm}")"

if [[ -n "${webphp_sgp_id}" ]]
then
   echo 'ERROR: The WebPhp security group is already created'
   exit 1
fi
  
webphp_sgp_id="$(create_security_group "${vpc_id}" "${webphp_sgp_nm}" \
                    "${webphp_sgp_nm} security group")"

echo "Created ${webphp_sgp_nm} Security Group"

allow_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
echo 'Granted SSH to development machine'

## ******** ##
## Database ##
## ******** ##

# Allow access to the database.
allow_access_from_security_group "${db_sgp_id}" "${DB_MMDATA_PORT}" "${webphp_sgp_id}"
echo 'Granted access to Database'

## ********* ##
## Admin box ##
## ********* ##

allow_access_from_security_group "${adm_sgp_id}" "${SERVER_ADMIN_RSYSLOG_PORT}" "${webphp_sgp_id}"
echo 'Granted access to Admin server rsyslog'

allow_access_from_security_group "${adm_sgp_id}" "${SERVER_ADMIN_MMONIT_HTTP_PORT}" "${webphp_sgp_id}"
echo 'Granted access to Admin server MMonit collector'

## *************** ##
## WebPhp instance ##
## *************** ##

echo "Creating '${webphp_nm}' WebPhp instance ..."
# The WebPhp instance is run from the secured Shared Image.
run_webphp_instance "${shared_base_ami_id}" "${webphp_nm}" "${webphp_sgp_id}" "${subnet_id}" "${key_pair_nm}"
webphp_instance_id="$(get_instance_id "${webphp_nm}")"
echo "WebPhp instance running"

## ********* ##
## Public IP ##
## ********* ##

echo 'Checking if there is any public IP avaiable in the account'
webphp_eip="$(get_public_ip_address_unused)"

if [[ -n "${webphp_eip}" ]]
then
   echo "Found '${webphp_eip}' unused public IP address"
else
   echo 'Not found any unused public IP address, a new one must be allocated'
   webphp_eip="$(allocate_public_ip_address)" 
   echo "The '${webphp_eip}' public IP address has been allocated to the account"
fi

associate_public_ip_address_to_instance "${webphp_eip}" "${webphp_instance_id}"
echo "The '${webphp_eip}' public IP address has been associated with the WebPhp instance"

## ******* ##
## Modules ## 
## ******* ##

# Prepare the scripts to run on the server.

sed -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDserver_webphp_hostnameSED/${webphp_hostname}/g" \
    -e "s/SEDloadbalancer_virtualhost_configSED/${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}/g" \
     -e "s/SEDloadbalancer_docroot_idSED/${LOADBALANCER_DOCROOT_ID}/g" \
    -e "s/SEDmonit_virtualhost_configSED/${MONIT_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDmonit_docroot_idSED/${MONIT_DOCROOT_ID}/g" \
       "${TEMPLATE_DIR}"/webphp/install_webphp_template.sh > "${TMP_DIR}"/"${webphp_dir}"/install_webphp.sh
    
echo 'install_webphp.sh ready'    
    
# Get the account number.
aws_account="$(get_account_number)"

# Make the AES key for PHP sessions.
# Its a hex encoded version of $PHP_SESSIONS_PWD
aes1="${PHP_SESSIONS_PWD}"
# Convert to hex
aes2="$(hexdump -e '"%X"' <<< "$aes1")"
# Lowercase
aes3="$(echo "${aes2}" | tr '[:upper:]' '[:lower:]')"
# Only the first 64 characters
aes4="${aes3:0:64}"

# Apache Web Server main configuration file.
sed -e "s/SEDapache_loadbalancer_portSED/${SERVER_APACHE_WEBPHP_LOADBALANCER_PORT}/g" \
    -e "s/SEDapache_website_portSED/${SERVER_APACHE_WEBPHP_WEBSITE_PORT}/g" \
    -e "s/SEDapache_monit_portSED/${SERVER_WEBPHP_APACHE_MONIT_PORT}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
    -e "s/SEDwebphp_emailSED/${SERVER_WEBPHP_EMAIL}/g" \
    -e "s/SEDdbhostSED/${db_endpoint}/g" \
    -e "s/SEDdbnameSED/${DB_MMDATA_NM}/g" \
    -e "s/SEDdbportSED/${DB_MMDATA_PORT}/g" \
    -e "s/SEDdbuser_webphprwSED/${webphp_db_user_nm}/g" \
    -e "s/SEDdbpass_webphprwSED/${DB_MMDATA_WEBPHP_USER_PWD}/g" \
    -e "s/SEDaws_accountSED/${aws_account}/g" \
    -e "s/SEDaws_deployregionSED/${DEPLOY_REGION}/g" \
    -e "s/SEDaeskeySED/${aes4}/g" \
    -e "s/SEDrecaptcha_privatekeySED/${RECAPTCHA_PRIVATE_KEY}/g" \
    -e "s/SEDrecaptcha_publickeySED/${RECAPTCHA_PUBLIC_KEY}/g" \
    -e "s/SEDserveridSED/${webphp_id}/g" \
       "${TEMPLATE_DIR}"/webphp/httpd/httpd_template.conf > "${TMP_DIR}"/"${webphp_dir}"/httpd.conf
       
echo 'httpd.conf ready'       
       
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
       
echo 'extend_apache_web_server_with_FCGI.sh ready' 

# Apache Web Server Security module
sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       -e "s/SEDowasp_archiveSED/${OWASP_ARCHIVE}/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_security_module_template.sh > \
       "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_security_module_template.sh     

echo 'extend_apache_web_server_with_security_module_template.sh ready'

# Script that sets a password for 'ec2-user' user.
sed -e "s/SEDuser_nameSED/ec2-user/g" \
    -e "s/SEDuser_pwdSED/${SERVER_WEBPHP_EC2_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/users/chp_user_template.exp > "${TMP_DIR}"/"${webphp_dir}"/chp_ec2-user.sh

echo 'chp_ec2-user.sh ready'

# Script that sets a password for 'root' user.
sed -e "s/SEDuser_nameSED/root/g" \
    -e "s/SEDuser_pwdSED/${SERVER_WEBPHP_ROOT_PWD}/g" \
       "${TEMPLATE_DIR}"/users/chp_user_template.exp > "${TMP_DIR}"/"${webphp_dir}"/chp_root.sh
  
echo 'chp_root.sh ready'  
  
# Monit demon configuration file (runs on all servers).
sed -e "s/SEDhostnameSED/${webphp_nm}/g" \
    -e "s/SEDserver_admin_private_ipSED/${SERVER_ADMIN_PRIVATE_IP}/g" \
    -e "s/SEDmmonit_collector_portSED/${SERVER_ADMIN_MMONIT_HTTP_PORT}/g" \
    -e "s/SEDapache_http_portSED/${SERVER_WEBPHP_APACHE_MONIT_PORT}/g" \
    -e "s/SEDadmin_emailSED/${SERVER_ADMIN_EMAIL}/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       "${TEMPLATE_DIR}"/webphp/monitrc_template > "${TMP_DIR}"/"${webphp_dir}"/monitrc        

echo 'monitrc ready'
    
# Create Monit heartbeat virtualhost to check Apache Web Server.   
create_virtualhost_configuration_file '127.0.0.1' \
                                       "${SERVER_WEBPHP_APACHE_MONIT_PORT}" \
                                       "${monit_request_domain}" \
                                       "${APACHE_DOCROOT_DIR}" \
                                       "${MONIT_DOCROOT_ID}" \
                                       "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}"     
 
# Enable Apache Web Server Monit heartbeat endpoint.                                       
add_alias_to_virtualhost 'monit' \
   "${APACHE_DOCROOT_DIR}" \
   "${MONIT_DOCROOT_ID}" \
   "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}"
   
echo "${MONIT_VIRTUALHOST_CONFIG_FILE} ready"   
       
# Create a Load Balancer healt-check virtualhost. 
create_virtualhost_configuration_file '*' \
                                       "${SERVER_WEBPHP_APACHE_LOADBALANCER_PORT}" \
                                       "${loadbalancer_request_domain}" \
                                       "${APACHE_DOCROOT_DIR}" \
                                       "${LOADBALANCER_DOCROOT_ID}" \
                                       "${TMP_DIR}"/"${webphp_dir}"/"${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}"   
 
# Enable the Load Balancer virtualhost.                                       
add_loadbalancer_rule_to_virtualhost 'elb.htm' \
   "${APACHE_DOCROOT_DIR}" \
   "${LOADBALANCER_DOCROOT_ID}" \
   "${TMP_DIR}"/"${webphp_dir}"/"${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" 

echo "${LOADBALANCER_VIRTUALHOST_CONFIG_FILE} ready" 
                
# Rsyslog configuration file.    
sed -e "s/SEDserver_admin_rsyslog_portSED/${SERVER_ADMIN_RSYSLOG_PORT}/g" \
    -e "s/SEDserver_admin_private_ip_addressSED/${SERVER_ADMIN_PRIVATE_IP}/g" \
       "${TEMPLATE_DIR}"/webphp/rsyslog_template.conf > "${TMP_DIR}"/"${webphp_dir}"/rsyslog.conf    

echo 'rsyslog.conf ready'
      
echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${webphp_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

echo 'Uploading files ...'
scp_upload_files "${private_key}" "${webphp_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
                 "${TMP_DIR}"/"${webphp_dir}"/install_webphp.sh \
                 "${TMP_DIR}"/"${webphp_dir}"/monitrc \
                 "${TMP_DIR}"/"${webphp_dir}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}" \
                 "${TMP_DIR}"/"${webphp_dir}"/"${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" \
                 "${TMP_DIR}"/"${webphp_dir}"/chp_root.sh \
                 "${TMP_DIR}"/"${webphp_dir}"/chp_ec2-user.sh \
                 "${TMP_DIR}"/"${webphp_dir}"/httpd.conf \
                 "${TMP_DIR}"/"${webphp_dir}"/install_apache_web_server.sh \
                 "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_FCGI.sh  \
                 "${TMP_DIR}"/"${webphp_dir}"/extend_apache_web_server_with_security_module_template.sh \
                 "${TMP_DIR}"/"${webphp_dir}"/rsyslog.conf  \
                 "${TEMPLATE_DIR}"/common/php/install_php.sh \
                 "${TEMPLATE_DIR}"/common/httpd/09-fcgid.conf \
                 "${TEMPLATE_DIR}"/common/httpd/10-fcgid.conf \
                 "${TEMPLATE_DIR}"/common/httpd/httpd-mpm.conf \
                 "${TEMPLATE_DIR}"/common/httpd/owasp_mod_security.conf \
                 "${TEMPLATE_DIR}"/common/php/php.ini \
                 "${TEMPLATE_DIR}"/webphp/httpd/modsecurity_overrides.conf \
                 "${JAR_DIR}"/"${OWASP_ARCHIVE}"
#
# Run the install script
#

echo 'Installing WebPhp modules ...'
ssh_run_remote_command 'chmod +x install_webphp.sh' \
                   "${private_key}" \
                   "${webphp_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" 

set +e                
ssh_run_remote_command './install_webphp.sh' \
                   "${private_key}" \
                   "${webphp_eip}" \
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
   echo 'Error running install_webphp.sh'
   exit 1
fi  

## ************* ##
## Load Balancer ##
## ************* ##

register_instance_with_loadbalancer "${LBAL_NM}" "${webphp_instance_id}"
echo 'Instance registered with Load Balancer'

allow_access_from_security_group "${webphp_sgp_id}" "${SERVER_WEBPHP_APACHE_LOADBALANCER_PORT}" "${loadbalancer_sgp_id}"
echo 'Granted Load Balancer access to the instance'
       
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
       
# Removing local temp files
# shellcheck disable=SC2115
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"

echo "WebPhp box set up completed, IP address: '${webphp_eip}'" 
echo
