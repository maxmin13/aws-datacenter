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
# install_selfsigned_certificates_template.sh
# install_letsencrypt_ca_certificates_template.sh
#
############################################################

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
SSL_CERT_FILE='SEDcert_fileSED'
SSL_KEY_FILE='SEDkey_fileSED'
admin_log_file='/var/log/admin_ssl_install.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

##
## Apache web server SSL module.
##

echo 'Configuring Apache web server SSL ...'
 
# Apache SSL module 
cd "${script_dir}" || exit 1

echo 'Installing Apache SSL module ...'

chmod +x extend_apache_web_server_with_SSL_module_template.sh 
./extend_apache_web_server_with_SSL_module_template.sh >> "${admin_log_file}" 2>&1 

echo 'Apache SSL module installed.'

##
## Apache Web server certificates. 
## 

cd "${script_dir}" || exit 1

chmod +x install_apache_web_server_certificates.sh
   
echo 'Installing Apache web server certificates ...'
   
set +e 
./install_apache_web_server_certificates.sh >> "${admin_log_file}" 2>&1
exit_code=$?
set -e 
   
if [[ ! 0 -eq "${exit_code}" ]]
then
   echo "ERROR: installing Apache web server certificates."     
   exit 1
fi 
  
echo 'Certificates installed in Apache web server.'

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

echo 'Phpmyadmin SSL configured.'

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

echo 'Loganalyzer SSL configured.'

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
   
   echo 'Admin website SSL configured.'
fi

# Check the syntax
httpd -t >> "${admin_log_file}" 2>&1 

systemctl restart httpd

echo 'Apache web server restarted.' >> "${admin_log_file}" 2>&1

##
## M/Monit
##

echo 'Configuring M/Monit SSL ...' >> "${admin_log_file}" 2>&1

cp -f server.xml "${MMONIT_INSTALL_DIR}"/conf

find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chmod 400 {} + 

echo 'M/Monit configuration file copied.' >> "${admin_log_file}" 2>&1 

cat "${SSL_KEY_FILE}" > "${MMONIT_INSTALL_DIR}"/conf/cert.pem
cat "${SSL_CERT_FILE}" >> "${MMONIT_INSTALL_DIR}"/conf/cert.pem
mv "${MMONIT_INSTALL_DIR}"/conf/cert.pem "${MMONIT_INSTALL_DIR}"/conf/"${SSL_CERT_FILE}"

find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chmod 400 {} +  

echo 'M/Monit certificate installed.' >> "${admin_log_file}" 2>&1

systemctl restart mmonit

echo 'M/Monit restarted.' >> "${admin_log_file}" 2>&1 
echo 'M/Monit SSL configured.'

exit 0

