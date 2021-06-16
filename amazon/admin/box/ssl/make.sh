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
   granted_certbot="$(check_access_from_cidr_is_granted "${sgp_id}" '80' '0.0.0.0/0')"  

   if [[ -z "${granted_certbot}" ]]
   then
      allow_access_from_cidr "${sgp_id}" '80' '0.0.0.0/0'
   
      echo 'Granted Certbot access to Admin box port 80.'
   fi  
fi

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
    
sed -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDapache_default_http_portSED/${SRV_ADMIN_APACHE_DEFAULT_HTTP_PORT}/g" \
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
       "${TEMPLATE_DIR}"/admin/ssl/install_admin_ssl_template.sh > "${TMP_DIR}"/"${ssl_dir}"/install_admin_ssl.sh

echo 'install_admin_ssl.sh ready.'

sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
    -e "s/SEDenvironmentSED/${ENV}/g" \
    -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
       "${TEMPLATE_DIR}"/common/httpd/extend_apache_web_server_with_SSL_module_template.sh > "${TMP_DIR}"/"${ssl_dir}"/extend_apache_web_server_with_SSL_module_template.sh
             
echo 'extend_apache_web_server_with_SSL_module_template.sh ready.'   

scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${ssl_dir}"/install_admin_ssl.sh \
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
   
if [[ 'development' == "${ENV}" ]]
then

   #
   # In development use a self-signed certificate.
   #
   
   dev_key_file='server.dev.key'
   dev_key_file_no_pwd='server.dev.key_no.pass'
   dev_crt_file='server.dev.crt'
   dev_crt_file_path="certificate=\"conf/${dev_crt_file}\""

   sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
       -e "s/SEDserver_admin_private_ipSED/${SRV_ADMIN_PRIVATE_IP}/g" \
       -e "s/SEDcollector_portSED/${SRV_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
       -e "s/SEDpublic_portSED/${SRV_ADMIN_MMONIT_HTTPS_PORT}/g" \
       -e "s/SEDssl_secureSED/true/g" \
       -e "s/SEDcertificate_fileSED/${dev_crt_file}/g" \
       -e "s/SEDcertificateSED/$(escape "${dev_crt_file_path}")/g" \
          "${TEMPLATE_DIR}"/admin/mmonit/server_template.xml > "${TMP_DIR}"/"${ssl_dir}"/server.xml       
       
   echo 'server.xml ready.'    

   scp_upload_file "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${ssl_dir}"/server.xml     
         
   # Apache Web Server SSL key generation script.
   sed -e "s/SEDkey_fileSED/${dev_key_file}/g" \
       -e "s/SEDkey_pwdSED/secret@123/g" \
          "${TEMPLATE_DIR}"/common/ssl/self_signed/gen-rsa_template.exp > "${TMP_DIR}"/"${ssl_dir}"/gen-rsa.sh

   echo 'gen-rsa.sh ready.'

   # Apache Web Server remove the password protection from the key script.
   sed -e "s/SEDkey_fileSED/${dev_key_file}/g" \
       -e "s/SEDnew_key_fileSED/${dev_key_file_no_pwd}/g" \
       -e "s/SEDkey_pwdSED/secret@123/g" \
          "${TEMPLATE_DIR}"/common/ssl/self_signed/remove-passphase_template.exp > "${TMP_DIR}"/"${ssl_dir}"/remove-passphase.sh   

   echo 'remove-passphase.sh ready.'

   crt_dev_country='IE'
   crt_dev_city='Dublin'
   crt_dev_organization='Maxmin'
   crt_dev_unit='web'
   
   # Apache Web Server create self-signed Certificate script.
   sed -e "s/SEDkey_fileSED/${dev_key_file}/g" \
       -e "s/SEDcert_fileSED/${dev_crt_file}/g" \
       -e "s/SEDcountrySED/${crt_dev_country}/g" \
       -e "s/SEDstate_or_provinceSED/${crt_dev_city}/g" \
       -e "s/SEDcitySED/${crt_dev_city}/g" \
       -e "s/SEDorganizationSED/${crt_dev_organization}/g" \
       -e "s/SEDunit_nameSED/${crt_dev_unit}/g" \
       -e "s/SEDcommon_nameSED/${SRV_ADMIN_HOSTNAME}/g" \
       -e "s/SEDemail_addressSED/${SRV_ADMIN_EMAIL}/g" \
          "${TEMPLATE_DIR}"/common/ssl/self_signed/gen-selfsign-cert_template.exp > "${TMP_DIR}"/"${ssl_dir}"/gen-selfsign-cert.sh

   echo 'gen-selfsign-cert.sh ready.'
       
   # Apache Web Server SSL configuration file.
   sed -e "s/SEDwebsite_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTPS_PORT}/g" \
       -e "s/SEDphpmyadmin_portSED/${SRV_ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT}/g" \
       -e "s/SEDloganalyzer_portSED/${SRV_ADMIN_APACHE_LOGANALYZER_HTTPS_PORT}/g" \
       -e "s/SEDkey_fileSED/${dev_key_file}/g" \
       -e "s/SEDcert_fileSED/${dev_crt_file}/g" \
          "${TEMPLATE_DIR}"/admin/httpd/ssl_template.conf > "${TMP_DIR}"/"${ssl_dir}"/ssl.conf 
          
   echo 'ssl.conf ready.'   
   
   scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${ssl_dir}"/gen-selfsign-cert.sh \
       "${TMP_DIR}"/"${ssl_dir}"/remove-passphase.sh \
       "${TMP_DIR}"/"${ssl_dir}"/gen-rsa.sh \
       "${TMP_DIR}"/"${ssl_dir}"/ssl.conf
else

   # cert.pem
# chain.pem
# fullchain.pem
# privkey.pem

#SSLCertificateKeyFile    ssl/SEDssl_certificate_key_fileSED
#SSLCertificateFile       ssl/SEDssl_certificate_fileSED
#SSLCertificateChainFile  ssl/SEDssl_certificate_chain_fileSED   

   #
   # In Production use Certbot SSL agent to get a certificate from Let's Encrypt.
   #

 ###### TODO fix cert paths
   
   sed -e "s/SEDserver_admin_public_ipSED/${eip}/g" \
       -e "s/SEDserver_admin_private_ipSED/${SRV_ADMIN_PRIVATE_IP}/g" \
       -e "s/SEDcollector_portSED/${SRV_ADMIN_MMONIT_COLLECTOR_PORT}/g" \
       -e "s/SEDpublic_portSED/${SRV_ADMIN_MMONIT_HTTP_PORT}/g" \
       -e "s/SEDssl_secureSED/true/g" \
       -e "s/SEDcertificateSED/certificate=\"$(escape conf/${dev_crt_file})\"/g" \
          "${TEMPLATE_DIR}"/admin/mmonit/server_template.xml > "${TMP_DIR}"/"${ssl_dir}"/server.xml       
       
   echo 'server.xml ready.'
   
   scp_upload_file "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${ssl_dir}"/server.xml         
   
   sed -e "s/SEDapache_install_dirSED/$(escape ${APACHE_INSTALL_DIR})/g" \
       -e "s/SEDapache_usrSED/${APACHE_USER}/g" \
       -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
       -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
       -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
       -e "s/SEDcertbot_virtualhost_fileSED/${CERTBOT_VIRTUALHOST_CONFIG_FILE}/g" \
       -e "s/SEDcertbot_docroot_idSED/${CERTBOT_DOCROOT_ID}/g" \
       -e "s/SEDemail_addressSED/${SRV_ADMIN_EMAIL}/g" \
       -e "s/SEDdns_domainSED/${SRV_ADMIN_DNS_SUB_DOMAIN}.${MAXMIN_TLD}/g" \
          "${TEMPLATE_DIR}"/ssl/ca/install_certbot_template.sh > "${TMP_DIR}"/"${ssl_dir}"/install_certbot.sh 
          
   echo 'install_certbot.sh ready.'     

   # Certboot HTTP virtualhost file.
   create_virtualhost_configuration_file "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" \
       '*' \
       '80' \
       "${MAXMIN_TLD}" \
       "${APACHE_DOCROOT_DIR}" \
       "${CERTBOT_DOCROOT_ID}"

   add_server_alias_to_virtualhost "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" \
       "${CERTBOT_DOCROOT_ID}" \
       "${APACHE_DOCROOT_DIR}" \
       "${CERTBOT_DOCROOT_ID}"

   echo "${CERTBOT_VIRTUALHOST_CONFIG_FILE} ready."  
   
 ###### TODO fix cert paths
   
   # Apache Web Server SSL configuration file.
   sed -e "s/SEDwebsite_portSED/${SRV_ADMIN_APACHE_WEBSITE_HTTPS_PORT}/g" \
       -e "s/SEDphpmyadmin_portSED/${SRV_ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT}/g" \
       -e "s/SEDloganalyzer_portSED/${SRV_ADMIN_APACHE_LOGANALYZER_HTTPS_PORT}/g" \
           "${TEMPLATE_DIR}"/admin/httpd/ssl_template.conf > "${TMP_DIR}"/"${ssl_dir}"/ssl.conf 
   
   echo 'ssl.conf ready.'    
   
   scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${ssl_dir}"/ssl.conf \
       "${TMP_DIR}"/"${ssl_dir}"/install_certbot.sh \
       "${TMP_DIR}"/"${ssl_dir}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" 
fi  
                  
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
   
   echo  
fi

if [[ 'production' == "${ENV}" ]]
then      
   granted_certbot="$(check_access_from_cidr_is_granted "${sgp_id}" '80' '0.0.0.0/0')"  
   
   if [[ -n "${granted_ssh}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" '80' "0.0.0.0/0"
   
      echo 'Revoked Certbot access to the Admin server.' 
      echo  
   fi
fi
    
# Removing local temp files
rm -rf "${TMP_DIR:?}"/"${ssl_dir}"  

echo
echo 'SSL installed in the Admin box.' 
echo