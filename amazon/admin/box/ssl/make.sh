#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# The script extends Apache web server by 
# installing the SSL module and creating a 
# self-signed certificate or requesting it to a
# Certificate authority. The certificate is 
# used to configure SSL for the web server and 
# M/Monit.
###############################################

APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_USER='apache'
CERTBOT_DOCROOT_ID='admin.maxmin.it' 
CERTBOT_VIRTUALHOST_CONFIG_FILE='certbot.virtualhost.maxmin.it.conf'
PHPMYADMIN_DOCROOT_ID='phpmyadmin.maxmin.it'
PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE='phpmyadmin.http.virtualhost.maxmin.it.conf'
PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE='phpmyadmin.https.virtualhost.maxmin.it.conf'
LOGANALYZER_DOCROOT_ID='loganalyzer.maxmin.it'
LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE='loganalyzer.http.virtualhost.maxmin.it.conf'
LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE='loganalyzer.https.virtualhost.maxmin.it.conf'
ADMIN_DOCROOT_ID='admin.maxmin.it'
ADMIN_HTTP_VIRTUALHOST_CONFIG_FILE='admin.http.virtualhost.maxmin.it.conf' 
ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE='admin.https.virtualhost.maxmin.it.conf' 
MMONIT_INSTALL_DIR='/opt/mmonit'
WEBSITE_DOCROOT_ID='admin.maxmin.it'
ssl_dir='ssl/certbot'

echo '*************'
echo 'Admin box SSL'
echo '*************'
echo

instance_id="$(get_instance_id "${SRV_ADMIN_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Admin box not found.'
   exit 1
else
   echo "* Admin box ID: ${instance_id}."   
fi

sgp_id="$(get_security_group_id "${SRV_ADMIN_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo 'ERROR: Admin Security Group not found.'
   exit 1
else
   echo "* Admin Security Group ID: ${sgp_id}."   
fi

eip="$(get_public_ip_address_associated_with_instance "${SRV_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   exit 1
else
   echo "* Admin public IP address: ${eip}."
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo '* ERROR: database not found.'
   exit 1
else
   echo "* database Endpoint: ${db_endpoint}."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${ssl_dir}"
mkdir -p "${TMP_DIR}"/"${ssl_dir}"

## 
## SSH access
## 

key_pair_file="$(get_keypair_file_path "${SRV_ADMIN_KEY_PAIR_NM}" "${SRV_ADMIN_ACCESS_DIR}")"

if [[ -z "${key_pair_file}" ]] 
then
   echo 'ERROR: not found Admin SSH access key.'
   
   exit 1
fi
    
granted_ssh="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_ssh}" ]]
then
   echo 'WARN: SSH access to the Admin box already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo 'Granted SSH access to the Admin box.'
fi
   
if [[ 'production' == "${ENV}" ]]
then      
   granted_certbot="$(check_access_from_cidr_is_granted "${sgp_id}" "${SRV_ADMIN_APACHE_CERTBOT_HTTP_PORT}" '0.0.0.0/0')"  

   if [[ -z "${granted_certbot}" ]]
   then
      allow_access_from_cidr "${sgp_id}" "${SRV_ADMIN_APACHE_CERTBOT_HTTP_PORT}" '0.0.0.0/0'
   
      echo 'Granted Certbot access to Admin box'
   fi  
fi

##
## Upload scripts.
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
    -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_SSL_module_template.sh > "${TMP_DIR}"/"${ssl_dir}"/extend_apache_web_server_with_SSL_module_template.sh
             
echo 'extend_apache_web_server_with_SSL_module_template.sh ready.'   

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${ssl_dir}"/extend_apache_web_server_with_SSL_module_template.sh \
    "${TEMPLATE_DIR}"/common/httpd/00-ssl.conf      
   
# Loganalyzer Virtual Host file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${ssl_dir}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${SRV_ADMIN_APACHE_LOGANALYZER_HTTPS_PORT}" \
    "${SRV_ADMIN_HOSTNAME}" \
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
    "${SRV_ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT}" \
    "${SRV_ADMIN_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${PHPMYADMIN_DOCROOT_ID}"    
           
add_alias_to_virtualhost "${TMP_DIR}"/"${ssl_dir}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    'phpmyadmin' \
    "${APACHE_DOCROOT_DIR}" \
    "${PHPMYADMIN_DOCROOT_ID}" \
    'phpmyadmin'                  

echo "${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE} ready."     

# Website virtualhost file.
create_virtualhost_configuration_file "${TMP_DIR}"/"${ssl_dir}"/"${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    '*' \
    "${SRV_ADMIN_APACHE_WEBSITE_HTTPS_PORT}" \
    "${SRV_ADMIN_HOSTNAME}" \
    "${APACHE_DOCROOT_DIR}" \
    "${ADMIN_DOCROOT_ID}"        
     
add_alias_to_virtualhost "${TMP_DIR}"/"${ssl_dir}"/"${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
    'admin' \
    "${APACHE_DOCROOT_DIR}" \
    "${ADMIN_DOCROOT_ID}" \
    'index.php' 
                      
echo "${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE} ready."  

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
     "${TMP_DIR}"/"${ssl_dir}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
     "${TMP_DIR}"/"${ssl_dir}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" \
     "${TMP_DIR}"/"${ssl_dir}"/"${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}"

# Names of certificates used in the configuration files (ssl.conf, server.xml).
key_file='key.pem'
key_file_no_pwd='key_no.pass.pem'
crt_file='cert.pem'
chain_file='chain.pem'
      
if [[ 'development' == "${ENV}" ]]
then

   #
   # In development use a self-signed certificate.
   #
   
   # Apache Web Server SSL key generation script.
   sed -e "s/SEDkey_fileSED/${key_file}/g" \
       -e "s/SEDkey_pwdSED/secret@123/g" \
          "${TEMPLATE_DIR}"/common/ssl/self_signed/gen-rsa_template.exp > "${TMP_DIR}"/"${ssl_dir}"/gen-rsa.sh

   echo 'gen-rsa.sh ready.'

   # Apache Web Server remove the password protection from the key script.
   sed -e "s/SEDkey_fileSED/${key_file}/g" \
       -e "s/SEDnew_key_fileSED/${key_file_no_pwd}/g" \
       -e "s/SEDkey_pwdSED/secret@123/g" \
          "${TEMPLATE_DIR}"/common/ssl/self_signed/remove-passphase_template.exp > "${TMP_DIR}"/"${ssl_dir}"/remove-passphase.sh   

   echo 'remove-passphase.sh ready.'

   # Apache Web Server create self-signed Certificate script.
   sed -e "s/SEDkey_fileSED/${key_file}/g" \
       -e "s/SEDcert_fileSED/${crt_file}/g" \
       -e "s/SEDcountrySED/${CRT_DEV_COUNTRY}/g" \
       -e "s/SEDstate_or_provinceSED/${CRT_DEV_CITY}/g" \
       -e "s/SEDcitySED/${CRT_DEV_CITY}/g" \
       -e "s/SEDorganizationSED/${CRT_DEV_ORGANIZATION}/g" \
       -e "s/SEDunit_nameSED/${CRT_DEV_UNIT}/g" \
       -e "s/SEDcommon_nameSED/${SRV_ADMIN_HOSTNAME}/g" \
       -e "s/SEDemail_addressSED/${SRV_ADMIN_EMAIL}/g" \
          "${TEMPLATE_DIR}"/common/ssl/self_signed/gen-selfsign-cert_template.exp > "${TMP_DIR}"/"${ssl_dir}"/gen-selfsign-cert.sh

   echo 'gen-selfsign-cert.sh ready.'
         
   scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
       "${TEMPLATE_DIR}"/common/ssl/self_signed/gen_certificates.sh \
       "${TMP_DIR}"/"${ssl_dir}"/gen-selfsign-cert.sh \
       "${TMP_DIR}"/"${ssl_dir}"/remove-passphase.sh \
       "${TMP_DIR}"/"${ssl_dir}"/gen-rsa.sh
else

   #
   # In production get a certificate from Let's Encrypt CA.
   #

   sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       -e "s/SEDapache_certbot_portSED/${SRV_ADMIN_APACHE_CERTBOT_HTTP_PORT}/g" \
       -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
       -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
       -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
       -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       -e "s/SEDcertbot_virtualhost_fileSED/${CERTBOT_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDcertbot_docroot_idSED/${CERTBOT_DOCROOT_ID}/g" \
       -e "s/SEDcrt_email_addressSED/${SRV_ADMIN_EMAIL}/g" \
       -e "s/SEDcrt_domainSED/${SRV_ADMIN_DNS_SUB_DOMAIN}.${MAXMIN_TLD}/g" \
          "${TEMPLATE_DIR}"/common/ssl/ca/gen_ca_certificates_template.sh > "${TMP_DIR}"/"${ssl_dir}"/gen_certificates.sh
          
   echo 'gen_certificates.sh ready.'     

   # Certboot HTTP virtualhost file.
   create_virtualhost_configuration_file "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" \
       '*' \
       "${SRV_ADMIN_APACHE_CERTBOT_HTTP_PORT}" \
       "${MAXMIN_TLD}" \
       "${APACHE_DOCROOT_DIR}" \
       "${CERTBOT_DOCROOT_ID}"

   add_server_alias_to_virtualhost "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" \
       "${CERTBOT_DOCROOT_ID}" \
       "${APACHE_DOCROOT_DIR}" \
       "${CERTBOT_DOCROOT_ID}"

   echo "${CERTBOT_VIRTUALHOST_CONFIG_FILE} ready."  
   
   scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${ssl_dir}"/gen_certificates.sh \
       "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" 
fi  

sed -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDmmonit_install_dirSED/$(escape ${MMONIT_INSTALL_DIR})/g" \
    -e "s/SEDmonit_http_portSED/${SRV_ADMIN_APACHE_MONIT_HTTP_PORT}/g" \
    -e "s/SEDphpmyadmin_http_portSED/${SRV_ADMIN_APACHE_PHPMYADMIN_HTTP_PORT}/g" \
    -e "s/SEDphpmyadmin_https_portSED/${SRV_ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT}/g" \
    -e "s/SEDphpmyadmin_http_virtualhost_fileSED/${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDphpmyadmin_https_virtualhost_fileSED/${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDloganalyzer_http_portSED/${SRV_ADMIN_APACHE_LOGANALYZER_HTTP_PORT}/g" \
    -e "s/SEDloganalyzer_https_portSED/${SRV_ADMIN_APACHE_LOGANALYZER_HTTPS_PORT}/g" \
    -e "s/SEDloganalyzer_http_virtualhost_fileSED/${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDloganalyzer_https_virtualhost_fileSED/${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_http_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTP_PORT}/g" \
    -e "s/SEDwebsite_https_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTPS_PORT}/g" \
    -e "s/SEDwebsite_docroot_idSED/${WEBSITE_DOCROOT_ID}/g" \
    -e "s/SEDwebsite_http_virtualhost_fileSED/${ADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_https_virtualhost_fileSED/${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDcertbot_docroot_idSED/${CERTBOT_DOCROOT_ID}/g" \
    -e "s/SEDkey_fileSED/${key_file}/g" \
    -e "s/SEDcert_fileSED/${crt_file}/g" \
    -e "s/SEDchain_fileSED/${chain_file}/g" \
       "${TEMPLATE_DIR}"/admin/ssl/install_admin_ssl_template.sh > "${TMP_DIR}"/"${ssl_dir}"/install_admin_ssl.sh

echo 'install_admin_ssl.sh ready.'
 
# Apache Web Server SSL configuration file.
sed -e "s/SEDwebsite_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTPS_PORT}/g" \
    -e "s/SEDphpmyadmin_portSED/${SRV_ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT}/g" \
    -e "s/SEDloganalyzer_portSED/${SRV_ADMIN_APACHE_LOGANALYZER_HTTPS_PORT}/g" \
       "${TEMPLATE_DIR}"/admin/httpd/ssl_template.conf > "${TMP_DIR}"/"${ssl_dir}"/ssl.conf 
          
   echo 'ssl.conf ready.'   
       
# M/Monit configuration file
  
# Insert the certificate='conf/server.dev.crt' attribute.       
xmlstarlet ed -i "Server/Service/Engine/Host[@name='SEDserver_admin_public_ipSED']" \
    -t attr -n 'certificate' -v "conf/${crt_file}" \
    "${TEMPLATE_DIR}"/admin/mmonit/server_template.xml > "${TMP_DIR}"/"${ssl_dir}"/server.xml  

# Insert the secure='true' attribute.
xmlstarlet ed --inplace -i "Server/Service/Connector[@address='SEDserver_admin_private_ipSED']" \
    -t attr -n 'secure' -v 'true' \
    "${TMP_DIR}"/"${ssl_dir}"/server.xml  
       
sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
    -e "s/SEDserver_admin_private_ipSED/${SRV_ADMIN_PRIVATE_IP}/g" \
    -e "s/SEDcollector_portSED/${SRV_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
    -e "s/SEDpublic_portSED/${SRV_ADMIN_MMONIT_HTTPS_PORT}/g" \
    -i "${TMP_DIR}"/"${ssl_dir}"/server.xml                         
       
echo 'server.xml ready.'
   
scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
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
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}" \
    "${SRV_ADMIN_USER_PWD}"

set +e   
          
ssh_run_remote_command_as_root "${remote_dir}/install_admin_ssl.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}" \
    "${SRV_ADMIN_USER_PWD}"   
                     
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 0 -eq "${exit_code}" ]
then 
   echo 'SSL successfully configured in the Admin box.' 
     
   ssh_run_remote_command "rm -rf ${remote_dir:?}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}"   
                   
   echo 'Cleared remote directory.'
else
   echo 'ERROR: configuring SSL in the Admin box.'
   
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

if [[ 'production' == "${ENV}" ]]
then      
   granted_certbot="$(check_access_from_cidr_is_granted "${sgp_id}" "${SRV_ADMIN_APACHE_CERTBOT_HTTP_PORT}" '0.0.0.0/0')"  
   
   if [[ -n "${granted_ssh}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${SRV_ADMIN_APACHE_CERTBOT_HTTP_PORT}" "0.0.0.0/0"
   
      echo 'Revoked Certbot access to the Admin server.'  
   fi
fi
    
# Removing local temp files
rm -rf "${TMP_DIR:?}"/"${ssl_dir}"  

echo
echo 'SSL installed in the Admin box.' 
echo
