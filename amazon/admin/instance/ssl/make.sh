#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################################
# The script extends Apache web server by installing the SSL module.
# In development environment it creates a self-signed certificate.
# In production environment it requests a certificate to Let's Encrypt certificate
# authority.
# The certificate is used to configure SSL for the Apache web server and M/Monit.
###################################################################################

APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_USER='apache' 
CERTBOT_VIRTUALHOST_CONFIG_FILE='certbot.virtualhost.maxmin.it.conf'
PHPMYADMIN_DOCROOT_ID='phpmyadmin.maxmin.it'
PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE='phpmyadmin.http.virtualhost.maxmin.it.conf'
PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE='phpmyadmin.https.virtualhost.maxmin.it.conf'
LOGANALYZER_DOCROOT_ID='loganalyzer.maxmin.it'
LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE='loganalyzer.http.virtualhost.maxmin.it.conf'
LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE='loganalyzer.https.virtualhost.maxmin.it.conf'
ADMIN_DOCROOT_ID='admin.maxmin.it'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='admin.http.virtualhost.maxmin.it.conf'
WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE='admin.https.virtualhost.maxmin.it.conf'
MMONIT_INSTALL_DIR='/opt/mmonit'
WEBSITE_DOCROOT_ID='admin.maxmin.it'
ssl_dir='ssl/certbot'

echo '*************'
echo 'SSL Admin box'
echo '*************'
echo

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo 'ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${sgp_id}."   
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   exit 1
else
   echo "* Admin public IP address: ${eip}."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${ssl_dir}"
mkdir -p "${TMP_DIR}"/"${ssl_dir}"

## 
## Key pair
## 

key_pair_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 

if [[ -z "${key_pair_file}" ]] 
then
   echo 'ERROR: not found Admin SSH access key.'
   
   exit 1
fi

## 
## Security group.
## 

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e

echo 'Granted SSH access to the Admin box.'
   
if [[ 'production' == "${ENV}" ]]
then
   set +e      
   allow_access_from_cidr "${sgp_id}" "${ADMIN_APACHE_CERTBOT_HTTP_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Granted Certbot access to Admin box'  
fi

##
## Upload scripts.
## 

echo 'Uploading the scripts to the Admin box ...'

remote_dir=/home/"${ADMIN_INST_USER_NM}"/script

wait_ssh_started "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}"  

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_SSL_module_template.sh > "${TMP_DIR}"/"${ssl_dir}"/extend_apache_web_server_with_SSL_module_template.sh
             
echo 'extend_apache_web_server_with_SSL_module_template.sh ready.'   

scp_upload_files "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${ssl_dir}"/extend_apache_web_server_with_SSL_module_template.sh \
    "${TEMPLATE_DIR}"/common/httpd/00-ssl.conf      
   
# Loganalyzer Virtual Host file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${ssl_dir}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${ADMIN_APACHE_LOGANALYZER_HTTPS_PORT}" \
    "${ADMIN_INST_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${LOGANALYZER_DOCROOT_ID}"        
     
add_alias_to_virtualhost "${TMP_DIR}"/"${ssl_dir}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    'loganalyzer' \
    "${APACHE_DOCROOT_DIR}" \
    "${LOGANALYZER_DOCROOT_ID}" \
    'loganalyzer'   
     
echo "${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE} ready."     

# Phpmyadmin Virtual Host file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${ssl_dir}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT}" \
    "${ADMIN_INST_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${PHPMYADMIN_DOCROOT_ID}"    
           
add_alias_to_virtualhost "${TMP_DIR}"/"${ssl_dir}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    'phpmyadmin' \
    "${APACHE_DOCROOT_DIR}" \
    "${PHPMYADMIN_DOCROOT_ID}" \
    'phpmyadmin'                  

echo "${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE} ready."     

# Website virtualhost file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${ssl_dir}"/"${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${ADMIN_APACHE_WEBSITE_HTTPS_PORT}" \
    "${ADMIN_INST_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${ADMIN_DOCROOT_ID}"        
     
add_alias_to_virtualhost "${TMP_DIR}"/"${ssl_dir}"/"${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    'admin' \
    "${APACHE_DOCROOT_DIR}" \
    "${ADMIN_DOCROOT_ID}" \
    'index.php' 
                      
echo "${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE} ready."  

scp_upload_files "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
     "${TMP_DIR}"/"${ssl_dir}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
     "${TMP_DIR}"/"${ssl_dir}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
     "${TMP_DIR}"/"${ssl_dir}"/"${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
if [[ 'development' == "${ENV}" ]]
then

   #
   # In development use a self-signed certificate.
   #
   
   sed -e "s/SEDadmin_docroot_dirSED/${ADMIN_DOCROOT_ID}/g" \
          "${TEMPLATE_DIR}"/common/ssl/selfsigned/request_selfsigned_certificate_template.sh > "${TMP_DIR}"/"${ssl_dir}"/request_selfsigned_certificate.sh   
   
   # Apache Web Server create selfsigned Certificate script.
   sed -e "s/SEDcountrySED/${DEV_ADMIN_CRT_COUNTRY_NM}/g" \
       -e "s/SEDstate_or_provinceSED/${DEV_ADMIN_CRT_PROVINCE_NM}/g" \
       -e "s/SEDcitySED/${DEV_ADMIN_CRT_CITY_NM}/g" \
       -e "s/SEDorganizationSED/${DEV_ADMIN_CRT_ORGANIZATION_NM}/g" \
       -e "s/SEDunit_nameSED/${DEV_ADMIN_CRT_UNIT_NM}/g" \
       -e "s/SEDcommon_nameSED/${ADMIN_INST_DNS_DOMAIN_NM}/g" \
       -e "s/SEDemail_addressSED/${ADMIN_INST_EMAIL}/g" \
          "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_certificate_template.sh > "${TMP_DIR}"/"${ssl_dir}"/gen_certificate.sh

   echo 'gen_selfsigned_certificate.sh ready.'
         
   scp_upload_files "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_selfsigned_certificate.sh \
       "${TMP_DIR}"/"${ssl_dir}"/request_selfsigned_certificate.sh \
       "${TMP_DIR}"/"${ssl_dir}"/gen_certificate.sh \
       "${TEMPLATE_DIR}"/common/ssl/selfsigned/remove_passphase.sh \
       "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_rsa.sh
else

   #
   # In production get a certificate from Let's Encrypt CA.
   #   
     
   sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
       -e "s/SEDapache_certbot_portSED/${ADMIN_APACHE_CERTBOT_HTTP_PORT}/g" \
       -e "s/SEDcertbot_virtualhost_config_fileSED/${CERTBOT_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDadmin_docroot_idSED/${ADMIN_DOCROOT_ID}/g" \
       -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
       -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       -e "s/SEDcrt_email_addressSED/${ADMIN_INST_EMAIL}/g" \
       -e "s/SEDcrt_domainSED/${ADMIN_INST_DNS_DOMAIN_NM}/g" \
          "${TEMPLATE_DIR}"/common/ssl/ca/request_ca_certificate_with_http_challenge_template.sh > "${TMP_DIR}"/"${ssl_dir}"/request_ca_certificate_with_http_challenge.sh
          
   echo 'request_ca_certificate_with_http_challenge.sh ready.'     

   # Certboot HTTP virtualhost file.
   create_virtualhost_configuration_file "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" \
       '*' \
       "${ADMIN_APACHE_CERTBOT_HTTP_PORT}" \
       "${MAXMIN_TLD}" \
       "${APACHE_DOCROOT_DIR}" \
       "${ADMIN_DOCROOT_ID}"

   add_server_alias_to_virtualhost "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" \
       "${ADMIN_DOCROOT_ID}" \
       "${APACHE_DOCROOT_DIR}" \
       "${ADMIN_DOCROOT_ID}"

   echo "${CERTBOT_VIRTUALHOST_CONFIG_FILE} ready."  
   
   scp_upload_files "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${ssl_dir}"/request_ca_certificate_with_http_challenge.sh \
       "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" 
fi  

sed -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDadmin_docroot_idSED/${ADMIN_DOCROOT_ID}/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
    -e "s/SEDphpmyadmin_http_portSED/${ADMIN_APACHE_PHPMYADMIN_HTTP_PORT}/g" \
    -e "s/SEDphpmyadmin_https_portSED/${ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT}/g" \
    -e "s/SEDphpmyadmin_http_virtualhost_fileSED/${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDphpmyadmin_https_virtualhost_fileSED/${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDloganalyzer_http_portSED/${ADMIN_APACHE_LOGANALYZER_HTTP_PORT}/g" \
    -e "s/SEDloganalyzer_https_portSED/${ADMIN_APACHE_LOGANALYZER_HTTPS_PORT}/g" \
    -e "s/SEDloganalyzer_http_virtualhost_fileSED/${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDloganalyzer_https_virtualhost_fileSED/${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_http_portSED/${ADMIN_APACHE_WEBSITE_HTTP_PORT}/g" \
    -e "s/SEDwebsite_https_portSED/${ADMIN_APACHE_WEBSITE_HTTPS_PORT}/g" \
    -e "s/SEDwebsite_docroot_idSED/${WEBSITE_DOCROOT_ID}/g" \
    -e "s/SEDwebsite_http_virtualhost_fileSED/${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_https_virtualhost_fileSED/${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}/g" \
       "${TEMPLATE_DIR}"/admin/ssl/install_admin_ssl_template.sh > "${TMP_DIR}"/"${ssl_dir}"/install_admin_ssl.sh

echo 'install_admin_ssl.sh ready.'
 
# Apache Web Server SSL configuration file.
sed -e "s/SEDwebsite_portSED/${ADMIN_APACHE_WEBSITE_HTTPS_PORT}/g" \
    -e "s/SEDphpmyadmin_portSED/${ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT}/g" \
    -e "s/SEDloganalyzer_portSED/${ADMIN_APACHE_LOGANALYZER_HTTPS_PORT}/g" \
       "${TEMPLATE_DIR}"/admin/httpd/ssl_template.conf > "${TMP_DIR}"/"${ssl_dir}"/ssl.conf 
          
   echo 'ssl.conf ready.'   
       
# M/Monit configuration file
  
# Insert the certificate='conf/cert.pem' attribute.       
xmlstarlet ed -i "Server/Service/Engine/Host[@name='SEDserver_admin_public_ipSED']" \
    -t attr -n 'certificate' -v "conf/cert.pem" \
    "${TEMPLATE_DIR}"/admin/mmonit/server_template.xml > "${TMP_DIR}"/"${ssl_dir}"/server.xml  

# Insert the secure='true' attribute.
xmlstarlet ed --inplace -i "Server/Service/Connector[@address='SEDserver_admin_private_ipSED']" \
    -t attr -n 'secure' -v 'true' \
    "${TMP_DIR}"/"${ssl_dir}"/server.xml  
       
sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
    -e "s/SEDserver_admin_private_ipSED/${ADMIN_INST_PRIVATE_IP}/g" \
    -e "s/SEDcollector_portSED/${ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDpublic_portSED/${ADMIN_MMONIT_HTTPS_PORT}/g" \
    -i "${TMP_DIR}"/"${ssl_dir}"/server.xml                         
       
echo 'server.xml ready.'
   
scp_upload_files "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${ssl_dir}"/install_admin_ssl.sh \
    "${TMP_DIR}"/"${ssl_dir}"/ssl.conf \
    "${TMP_DIR}"/"${ssl_dir}"/server.xml  
                  
echo 'Scripts uploaded.'
     
## 
## Remote commands that have to be executed as priviledged user are run with sudo.
## By AWS default, sudo has not password.
## 

echo 'Installing SSL in the Admin box ...'
    
ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_admin_ssl.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}"

set +e   
          
ssh_run_remote_command_as_root "${remote_dir}/install_admin_ssl.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}"   
                     
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 0 -eq "${exit_code}" ]
then 
   echo 'SSL successfully configured in the Admin box.' 
     
   ssh_run_remote_command "rm -rf ${remote_dir:?}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"   
                   
   echo 'Cleared remote directory.'
else
   echo 'ERROR: configuring SSL in the Admin box.'
   
   exit 1
fi
      
## 
## SSH Access.
##

# Revoke SSH access from the development machine

set +e
revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Admin box.' 

if [[ 'production' == "${ENV}" ]]
then  
   set +e    
   revoke_access_from_cidr "${sgp_id}" "${ADMIN_APACHE_CERTBOT_HTTP_PORT}" 'tcp' "0.0.0.0/0" > /dev/null 2>&1
   set -e
   
   echo 'Revoked Certbot access to the Admin server.'
fi
    
# Removing local temp files
rm -rf "${TMP_DIR:?}"/"${ssl_dir}"  

echo
