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
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
MMONIT_INSTALL_DIR='SEDmmonit_install_dirSED'
PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDphpmyadmin_https_virtualhost_fileSED'
LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDloganalyzer_https_virtualhost_fileSED'
ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDadmin_https_virtualhost_fileSED' 
admin_log_file='/var/log/admin_ssl_install.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## 
## Apache SSL module 
## 

cd "${script_dir}" || exit

echo 'Installing Apache SSL module ...'

chmod +x extend_apache_web_server_with_SSL_module_template.sh 
./extend_apache_web_server_with_SSL_module_template.sh >> "${admin_log_file}" 2>&1 

echo 'Apache SSL module installed.'

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
## M/Monit
##
   
cp "${cert_file_nm}" "${MMONIT_INSTALL_DIR}"/conf

echo "Copied ${cert_file_nm} to Apache install directory"

cp "${key_file_nm}" "${MMONIT_INSTALL_DIR}"/conf

echo "Copied ${key_file_nm} to Apache install directory"

find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${MMONIT_INSTALL_DIR}"/conf -type f -exec chmod 400 {} +  

echo 'M/Monit certificate installed.'
 
cp -f server.xml "${MMONIT_INSTALL_DIR}"/conf/server.xml
chown root:root "${MMONIT_INSTALL_DIR}"/conf/server.xml
chmod 400 "${MMONIT_INSTALL_DIR}"/conf/server.xml

echo 'M/Monit configuration file copied.' 

systemctl restart mmonit

echo 'M/Monit restarted.' 

##
## Apache web server
##

cp -f httpd.conf "${APACHE_INSTALL_DIR}"/conf

find "${APACHE_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${APACHE_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf -type f -exec chmod 400 {} +   
   
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

##
## Virtualhosts
##

# Enable the phpmyadmin website.

cp "${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" ]]
then
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Phpmyadmin website enabled' >> "${admin_log_file}"
fi

# Enable the loganalyzer website.

cp "${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" ]]
then
   # Enable the and Loganalyzer site.  
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Loganalyzer website enabled' >> "${admin_log_file}"
fi

# Enable the Admin website.

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" ]]
then
   cp -f "${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${ADMIN_HTTPS_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Admin website enabled' >> "${admin_log_file}"
fi

# Check the syntax
httpd -t
   
echo 'Apache web server certificate installed.' 

systemctl restart httpd

echo 'Apache web server restarted.'  

echo '-------------------------------------------------'
echo 'Directory modules:'
ls -lh "${APACHE_INSTALL_DIR}"/modules
echo '-------------------------------------------------'
echo 'Modules compiled statically into the server:'
/usr/sbin/httpd -l
echo '-------------------------------------------------'
echo 'Modules compiled dynamically enabled with Apache:'
/usr/sbin/httpd -M
echo '-------------------------------------------------'
echo 'Server version:'
/usr/sbin/httpd -V
echo '-------------------------------------------------'

exit 0



