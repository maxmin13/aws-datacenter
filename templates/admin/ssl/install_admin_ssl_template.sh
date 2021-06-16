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
# gen-rsa.sh
# remove-passphase.sh
# gen-selfsign-cert.sh
# install_certbot.sh
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
MONIT_HTTP_PORT='SEDmonit_http_portSED'
admin_log_file='/var/log/admin_ssl_install.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

##
## SSL certificates 
## 

cd "${script_dir}" || exit

echo 'Requesting SSL certificates ...'

if [[ 'development' == "${ENV}" ]]
then
   
   #
   # In development, use a self-signed certificate.
   #
   
   echo 'Generating self-signed certificate ...'

   amazon-linux-extras install epel -y >> "${admin_log_file}" 2>&1
   yum install -y expect >> "${admin_log_file}" 2>&1

   chmod +x gen-rsa.sh \
            remove-passphase.sh \
            gen-selfsign-cert.sh

   key_file_nm="$(./gen-rsa.sh)" 
   new_key_file_nm="$(./remove-passphase.sh)" 
   rm "${key_file_nm}"
   mv "${new_key_file_nm}" "${key_file_nm}"
   
   echo 'No-password private key generated.'

   cert_file_nm="$(./gen-selfsign-cert.sh)"
   
   echo 'Self-signed certificate created.'
    
   yum remove -y expect >> "${admin_log_file}" 2>&1
   amazon-linux-extras disable epel -y >> "${admin_log_file}" 2>&1   

else

   #
   # In production request a certificate to Let's Encrypt CA.    
   #
      
   chmod +x install_certbot.sh
   
   echo 'Running Certbot ...'
   
   set +e 
   ./install_certbot.sh >> "${admin_log_file}" 2>&1 
   
   exit_code=$?
   set -e 
   
   if [[ ! 0 -eq "${exit_code}" ]]
   then
      echo "ERROR: running Certbot."
      exit 1
   fi  
   
   # /etc/letsencrypt/live/admin.maxmin.it
# cert.pem
# chain.pem
# fullchain.pem
# privkey.pem
   
   ### TODO create links to these files in apache
   
        
fi

##
## Apache web server
##

echo 'Configuring Apache web server SSL ...'
 
# Apache SSL module 
cd "${script_dir}" || exit

echo 'Installing Apache SSL module ...'

chmod +x extend_apache_web_server_with_SSL_module_template.sh 
./extend_apache_web_server_with_SSL_module_template.sh >> "${admin_log_file}" 2>&1 

echo 'Apache SSL module installed.'

# Copy the certificates.

cp "${cert_file_nm}" "${APACHE_INSTALL_DIR}"/ssl
cp "${key_file_nm}" "${APACHE_INSTALL_DIR}"/ssl
   
find "${APACHE_INSTALL_DIR}"/ssl -type d -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/ssl -type d -exec chmod 500 {} +
find "${APACHE_INSTALL_DIR}"/ssl -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/ssl -type f -exec chmod 400 {} +   

# Enable the certificate paths.
sed -i "s/^#SSLCertificateKeyFile/SSLCertificateKeyFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
sed -i "s/^#SSLCertificateFile/SSLCertificateFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
### sed -i "s/^#SSLCertificateChainFile/SSLCertificateChainFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

echo 'Apache web server certificate installed.'

##
## Phpmyadmin website
##

sed -i "s/^Listen \+${PHPMYADMIN_HTTP_PORT}$/#Listen ${PHPMYADMIN_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
sed -i "s/^#Listen \+${PHPMYADMIN_HTTPS_PORT}/Listen ${PHPMYADMIN_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

echo "Phpmyadmin listen on ${PHPMYADMIN_HTTPS_PORT} port enabled."

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}"

echo 'Phpmyadmin HTTP website disabled' >> "${admin_log_file}"
 
cp "${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" ]]
then
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Phpmyadmin HTPPS website enabled' >> "${admin_log_file}"
fi

##
## Loganalyzer website
##

sed -i "s/^Listen \+${LOGANALYZER_HTTP_PORT}$/#Listen ${LOGANALYZER_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
sed -i "s/^#Listen \+${LOGANALYZER_HTTPS_PORT}/Listen ${LOGANALYZER_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

echo "Loganalyzer listen on ${LOGANALYZER_HTTPS_PORT} port enabled."

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}"

echo 'Loganalyzer HTTP website disabled' >> "${admin_log_file}"

cp "${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" ]]
then 
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Loganalyzer HTTPS website enabled' >> "${admin_log_file}"
fi

##
## Monit
##

sed -i "s/^Listen \+${MONIT_HTTP_PORT}$/#Listen ${MONIT_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo "Enabled Apache web server listen on port ${MONIT_HTTP_PORT}." 

##
## Admin website
##

https_virhost="${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}"
website_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"

# Check if the website is installed.
if [[ -d "${website_dir}" ]]
then
   sed -i "s/^Listen \+${WEBSITE_HTTP_PORT}$/#Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf
   sed -i "s/^#Listen \+${WEBSITE_HTTPS_PORT}/Listen ${WEBSITE_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
   
   echo "Admin website listen on ${WEBSITE_HTTPS_PORT} port enabled."
   
   rm -f "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}"

   echo 'Admin HTTP website disabled' >> "${admin_log_file}"   

   cp -f "${https_virhost}" "${APACHE_SITES_AVAILABLE_DIR}"
   
   if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${https_virhost}" ]]
   then
      ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${https_virhost}" "${APACHE_SITES_ENABLED_DIR}"/"${https_virhost}"
   
      echo 'Admin HTTPS website enabled' >> "${admin_log_file}"
   fi
fi

# Check the syntax
httpd -t >> "${admin_log_file}" 2>&1 

systemctl restart httpd

echo 'Apache web server restarted.' 

##
## M/Monit
##

echo 'Configuring M/Monit SSL ...'

cp -f server.xml "${MMONIT_INSTALL_DIR}"/conf

find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chmod 400 {} + 

echo 'M/Monit configuration file copied.' 

cat "${key_file_nm}" > "${MMONIT_INSTALL_DIR}"/conf/"${cert_file_nm}"
cat "${cert_file_nm}" >> "${MMONIT_INSTALL_DIR}"/conf/"${cert_file_nm}"

find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chmod 400 {} +  

echo 'M/Monit certificate installed.'

systemctl restart mmonit

echo 'M/Monit restarted.'  

exit 0

