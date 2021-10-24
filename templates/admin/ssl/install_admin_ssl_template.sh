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
#
# Production environment:
#
# The directory where Certbot saves the certificates is:
#
# /etc/letsencrypt/live/admin.maxmin.it/
#
# The files cretaed are:
#
# cert.pem
# chain.pem
# fullchain.pem
# privkey.pem
# 
# Development environment:
# 
# The directory where the self-signed certificated is saved is:
#
# /etc/self-signed/live/admin.maxmin.it/
#
# The certificates are:
#
# key.pem
# cert.pem
#
###################################################################################

ENV='SEDenvironmentSED'
APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
ADMIN_DOCROOT_ID='SEDadmin_docroot_idSED'
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
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='SEDwebsite_http_virtualhost_fileSED'
WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDwebsite_https_virtualhost_fileSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
admin_log_file='/var/log/admin_ssl_install.log'

############### TODO error retrieving current directory: getcwd: cannot access parent directories: No such file or directory
############### 
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
############### 
############### 

### TODO pass SEDadmin_inst_user_nmSED value
# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

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

echo 'Requesting SSL certificate ...'

cd "${script_dir}" || exit 1

cert_dir=''
cert_file=''
key_file=''   
chain_file=''

if [[ 'development' == "${ENV}" ]]
then

   #
   # In development the certificate is self-signed.
   # The certificate is created in the directory:
   # /etc/self-signed/live/admin.maxmin.it/
   # key.pem
   # cert.pem
   
   chmod +x request_selfsigned_certificate.sh
   ./request_selfsigned_certificate.sh >> "${admin_log_file}" 2>&1
   exit_code=$? 
   
   cert_dir=/etc/self-signed/live/"${ADMIN_DOCROOT_ID}"
   cert_file=cert.pem
   key_file=key.pem
else

   #
   # In production the certificate is signed by Let's Encrypt CA.
   # The certificate is created in the directory:
   # /etc/letsencrypt/live/admin.maxmin.it/
   # cert.pem
   # chain.pem
   # fullchain.pem
   # privkey.pem
   
   chmod +x request_ca_certificate_with_http_challenge.sh 
   ./request_ca_certificate_with_http_challenge.sh >> "${admin_log_file}" 2>&1
   exit_code=$?
   
   cert_dir=/etc/letsencrypt/live/"${ADMIN_DOCROOT_ID}"
   cert_file=cert.pem
   key_file=privkey.pem   
   chain_file=fullchain.pem
fi

if [[ ! 0 -eq "${exit_code}" ]]
then
   echo "ERROR: requesting SSL certificate."     
   exit 1
fi

echo 'SSL Certificate successfully requested.'

##
## Apache web server 
## 

echo 'Configuring Apache web server SSL ...'

rm -f "${APACHE_INSTALL_DIR}"/ssl/key.pem
ln -s "${cert_dir}"/"${key_file}" "${APACHE_INSTALL_DIR}"/ssl/key.pem
sed -i "s/^#SSLCertificateKeyFile/SSLCertificateKeyFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
   
rm -f "${APACHE_INSTALL_DIR}"/ssl/cert.pem
ln -s "${cert_dir}"/"${cert_file}" "${APACHE_INSTALL_DIR}"/ssl/cert.pem
sed -i "s/^#SSLCertificateFile/SSLCertificateFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

if [[ -n "${chain_file}" ]]
then
   rm -f "${APACHE_INSTALL_DIR}"/ssl/chain.pem
   ln -s "${cert_dir}"/"${chain_file}" "${APACHE_INSTALL_DIR}"/ssl/chain.pem
   sed -i "s/^#SSLCertificateChainFile/SSLCertificateChainFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
fi
   
echo 'Created key and certificate symlinks for ssl.conf configuration file.' >> "${admin_log_file}" 2>&1
echo 'Apache web server SSL successfully configured.'
  
##
## Phpmyadmin website.
##

# Disable HTTP ports and enable HTTPS ports in Apache config.
sed -i "s/^Listen \+${PHPMYADMIN_HTTP_PORT}$/#Listen ${PHPMYADMIN_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
sed -i "s/^#Listen \+${PHPMYADMIN_HTTPS_PORT}/Listen ${PHPMYADMIN_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

echo "Apache web server listen on ${PHPMYADMIN_HTTPS_PORT} Phpmyadmin website port enabled." >> "${admin_log_file}" 2>&1

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}"

echo 'Phpmyadmin HTTP virtual host disabled' >> "${admin_log_file}"
 
cp "${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}"
ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
echo 'Phpmyadmin HTPPS virtual host enabled' >> "${admin_log_file}"
echo 'Phpmyadmin SSL successfully configured.'

##
## Loganalyzer website.
##

# Disable HTTP ports and enable HTTPS ports in Apache config.
sed -i "s/^Listen \+${LOGANALYZER_HTTP_PORT}$/#Listen ${LOGANALYZER_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
sed -i "s/^#Listen \+${LOGANALYZER_HTTPS_PORT}/Listen ${LOGANALYZER_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

echo "Apache web server listen on ${LOGANALYZER_HTTPS_PORT} Loganalyzer website port enabled." >> "${admin_log_file}" 2>&1

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}"

echo 'Loganalyzer HTTP virtual host disabled' >> "${admin_log_file}"

cp "${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}"
ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
echo 'Loganalyzer HTTPS virtual host enabled' >> "${admin_log_file}"
echo 'Loganalyzer SSL successfully configured.'

https_virhost="${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}"
website_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"

# Check if the website is installed.
if [[ -d "${website_dir}" ]]
then
   # Disable HTTP ports and enable HTTPS ports in Apache config.
   sed -i "s/^Listen \+${WEBSITE_HTTP_PORT}$/#Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
   sed -i "s/^#Listen \+${WEBSITE_HTTPS_PORT}/Listen ${WEBSITE_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
   
   echo "Apache web server listen on ${WEBSITE_HTTPS_PORT} Admin website port enabled." >> "${admin_log_file}" 2>&1
   
   rm -f "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}"

   echo 'Admin HTTP virtual host disabled' >> "${admin_log_file}"   

   cp -f "${https_virhost}" "${APACHE_SITES_AVAILABLE_DIR}"
   
   rm -f "${APACHE_SITES_ENABLED_DIR}"/"${https_virhost}"
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${https_virhost}" "${APACHE_SITES_ENABLED_DIR}"/"${https_virhost}"
   
   echo 'Admin HTTPS virtual host enabled' >> "${admin_log_file}"
   echo 'Admin website SSL successfully configured.'
else
   echo 'WARN: Admin website not found.'
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

rm -f "${MMONIT_INSTALL_DIR}"/conf/cert.pem

cat "${cert_dir}"/"${key_file}" > "${MMONIT_INSTALL_DIR}"/conf/cert.pem

if [[ -n "${chain_file}" ]]
then
   cat "${cert_dir}"/"${chain_file}" >> "${MMONIT_INSTALL_DIR}"/conf/cert.pem
else
   cat "${cert_dir}"/"${cert_file}" >> "${MMONIT_INSTALL_DIR}"/conf/cert.pem
fi

echo 'M/Monit certificate installed.' >> "${admin_log_file}" 2>&1  

find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chmod 400 {} + 

systemctl restart mmonit

echo 'M/Monit restarted.' >> "${admin_log_file}" 2>&1 
echo 'M/Monit SSL successfully configured.'

exit 0

