#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

############################################################
# Extends Apache web server with the SSL module.
# Configures SSL for Apache web server and M/Monit.
# In development a self-signed certificate is used, in  
# production, a certificate signed by Let's Encrypt CA is 
# used.
#
# Dependencies:
#
# extend_apache_web_server_with_SSL_module_template.sh
# request_ca_certificate.sh
# gen_selfsigned_certificate.sh
#
############################################################

ENV='SEDenvironmentSED'
APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
MMONIT_INSTALL_DIR='SEDmmonit_install_dirSED'
PHPMYADMIN_HTTP_PORT='SEDphpmyadmin_http_portSED'
PHPMYADMIN_HTTPS_PORT='SEDphpmyadmin_https_portSED'
PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE='SEDphpmyadmin_http_virtualhost_fileSED'
PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDphpmyadmin_https_virtualhost_fileSED'
LOGANALYZER_HTTP_PORT='SEDloganalyzer_http_portSED'
LOGANALYZER_HTTPS_PORT='SEDloganalyzer_https_portSED'
LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE='SEDloganalyzer_http_virtualhost_fileSED'
LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDloganalyzer_https_virtualhost_fileSED'
WEBSITE_HTTP_PORT='SEDwebsite_http_portSED'
WEBSITE_HTTPS_PORT='SEDwebsite_https_portSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='SEDwebsite_http_virtualhost_fileSED' 
WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDwebsite_https_virtualhost_fileSED' 
CERTBOT_DOCROOT_ID='SEDcertbot_docroot_idSED'
KEY_FILE='SEDkey_fileSED'
CERT_FILE='SEDcert_fileSED'
CHAIN_FILE='SEDchain_fileSED'
admin_log_file='/var/log/admin_ssl_install.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Configuring Admin box SSL ...'
 
##
## Apache web server SSL module.
##

cd "${script_dir}" || exit 1

echo 'Installing Apache SSL module ...'

chmod +x extend_apache_web_server_with_SSL_module_template.sh 
./extend_apache_web_server_with_SSL_module_template.sh >> "${admin_log_file}" 2>&1 

echo 'Apache SSL module installed.'

##
## SSL certifcates 
## 

echo 'Generating SSL certificate ...'

cd "${script_dir}" || exit 1

if [[ 'development' == "${ENV}" ]]
then
   chmod +x gen_selfsigned_certificate.sh    
   set +e 
   ./gen_selfsigned_certificate.sh >> "${admin_log_file}" 2>&1
   exit_code=$?
   set -e 
else
   # Request a certificate to Let's Encrypt CA.
   chmod +x request_ca_certificate.sh
   set +e 
   ./request_ca_certificate.sh >> "${admin_log_file}" 2>&1
   exit_code=$?
   set -e 
fi

if [[ ! 0 -eq "${exit_code}" ]]
then
   echo "ERROR: generating SSL certificate."     
   exit 1
fi

echo 'SSL Certificate successfully generated.'

##
## Apache web server 
## 

echo 'Configuring Apache web server SSL ...'

if [[ 'development' == "${ENV}" ]]
then

   # Self-signed certificate and key are in the current directory.

   cp "${CERT_FILE}" "${APACHE_INSTALL_DIR}"/ssl
   cp "${KEY_FILE}" "${APACHE_INSTALL_DIR}"/ssl
   
   echo 'Certificate and key copied in Apache web server directory.' >> "${admin_log_file}" 2>&1

   find "${APACHE_INSTALL_DIR}"/ssl -type d -exec chown root:root {} +
   find "${APACHE_INSTALL_DIR}"/ssl -type d -exec chmod 500 {} +
   find "${APACHE_INSTALL_DIR}"/ssl -type f -exec chown root:root {} +
   find "${APACHE_INSTALL_DIR}"/ssl -type f -exec chmod 400 {} +

   # Enable the certificate paths.
   sed -i "s/^#SSLCertificateKeyFile/SSLCertificateKeyFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
   sed -i "s/^#SSLCertificateFile/SSLCertificateFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf 

   echo 'Certificate and key paths enabled in ssl.conf.' >> "${admin_log_file}" 2>&1

else

   # Let''s Encrypt certificates are in /etc/letsencrypt/live/admin.maxmin.it directory.

   # Link the certificate paths with certificates obtained from Let's Encrypt.
   if [[ ! -f "${APACHE_INSTALL_DIR}"/ssl/"${KEY_FILE}" ]]
   then
      ln -s /etc/letsencrypt/live/"${CERTBOT_DOCROOT_ID}"/privkey.pem "${APACHE_INSTALL_DIR}"/ssl/"${KEY_FILE}"
   fi
   
   if [[ ! -f "${APACHE_INSTALL_DIR}"/ssl/"${CERT_FILE}" ]]
   then
      ln -s /etc/letsencrypt/live/"${CERTBOT_DOCROOT_ID}"/cert.pem "${APACHE_INSTALL_DIR}"/ssl/"${CERT_FILE}"
   fi
   
   if [[ ! -f "${APACHE_INSTALL_DIR}"/ssl/"${CHAIN_FILE}" ]]
   then
      ln -s /etc/letsencrypt/live/"${CERTBOT_DOCROOT_ID}"/chain.pem "${APACHE_INSTALL_DIR}"/ssl/"${CHAIN_FILE}"
   fi

   echo 'ssl.conf paths linked with the certificates obtained from Let''s Encrypt.' >> "${admin_log_file}" 2>&1

   # Enable the certificate paths.
   sed -i "s/^#SSLCertificateKeyFile/SSLCertificateKeyFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
   sed -i "s/^#SSLCertificateFile/SSLCertificateFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
   sed -i "s/^#SSLCertificateChainFile/SSLCertificateChainFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

   echo 'Certificate, key and chain paths enabled in ssl.conf.' >> "${admin_log_file}" 2>&1

fi

echo 'Apache web server SSL successfully configured.'
  
##
## Phpmyadmin website.
##

sed -i "s/^Listen \+${PHPMYADMIN_HTTP_PORT}$/#Listen ${PHPMYADMIN_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
sed -i "s/^#Listen \+${PHPMYADMIN_HTTPS_PORT}/Listen ${PHPMYADMIN_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

echo "Apache web server listen on ${PHPMYADMIN_HTTPS_PORT} Phpmyadmin website port enabled." >> "${admin_log_file}" 2>&1

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}"

echo 'Phpmyadmin HTTP virtual host disabled' >> "${admin_log_file}"
 
cp "${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" ]]
then
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Phpmyadmin HTPPS virtual host enabled' >> "${admin_log_file}"
fi

echo 'Phpmyadmin SSL successfully configured.'

##
## Loganalyzer website.
##

sed -i "s/^Listen \+${LOGANALYZER_HTTP_PORT}$/#Listen ${LOGANALYZER_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
sed -i "s/^#Listen \+${LOGANALYZER_HTTPS_PORT}/Listen ${LOGANALYZER_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

echo "Apache web server listen on ${LOGANALYZER_HTTPS_PORT} Loganalyzer website port enabled." >> "${admin_log_file}" 2>&1

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}"

echo 'Loganalyzer HTTP virtual host disabled' >> "${admin_log_file}"

cp "${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" ]]
then 
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Loganalyzer HTTPS virtual host enabled' >> "${admin_log_file}"
fi

echo 'Loganalyzer SSL successfully configured.'

https_virhost="${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}"
website_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"

# Check if the website is installed.
if [[ -d "${website_dir}" ]]
then
   sed -i "s/^Listen \+${WEBSITE_HTTP_PORT}$/#Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
   sed -i "s/^#Listen \+${WEBSITE_HTTPS_PORT}/Listen ${WEBSITE_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
   
   echo "Apache web server listen on ${WEBSITE_HTTPS_PORT} Admin website port enabled." >> "${admin_log_file}" 2>&1
   
   rm -f "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}"

   echo 'Admin HTTP virtual host disabled' >> "${admin_log_file}"   

   cp -f "${https_virhost}" "${APACHE_SITES_AVAILABLE_DIR}"
   
   if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${https_virhost}" ]]
   then
      ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${https_virhost}" "${APACHE_SITES_ENABLED_DIR}"/"${https_virhost}"
   
      echo 'Admin HTTPS virtual host enabled' >> "${admin_log_file}"
   fi
   
   echo 'Admin website SSL successfully configured.'
fi

# Check the syntax
httpd -t >> "${admin_log_file}" 2>&1 

systemctl restart httpd

echo 'Apache web server restarted.' >> "${admin_log_file}" 2>&1

##
## M/Monit
##

echo 'Configuring M/Monit SSL ...'

cp -f server.xml "${MMONIT_INSTALL_DIR}"/conf

find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chmod 400 {} + 

echo 'M/Monit configuration file copied.' >> "${admin_log_file}" 2>&1 

if [[ 'development' == "${ENV}" ]]
then

   cat "${KEY_FILE}" > "${MMONIT_INSTALL_DIR}"/conf/"${CERT_FILE}"
   cat "${CERT_FILE}" >> "${MMONIT_INSTALL_DIR}"/conf/"${CERT_FILE}"
   
   find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
   find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
   find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
   find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chmod 400 {} +    

   echo 'M/Monit development certificate installed.' >> "${admin_log_file}" 2>&1
   
else

   cat /etc/letsencrypt/live/"${CERTBOT_DOCROOT_ID}"/privkey.pem > "${MMONIT_INSTALL_DIR}"/conf/"${CERT_FILE}"
   cat /etc/letsencrypt/live/"${CERTBOT_DOCROOT_ID}"/fullchain.pem >> "${MMONIT_INSTALL_DIR}"/conf/"${CERT_FILE}"

   echo 'M/Monit production certificate installed.' >> "${admin_log_file}" 2>&1
   
fi

systemctl restart mmonit

echo 'M/Monit restarted.' >> "${admin_log_file}" 2>&1 
echo 'M/Monit SSL successfully configured.'

exit 0

