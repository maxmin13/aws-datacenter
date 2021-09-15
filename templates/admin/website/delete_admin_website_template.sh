#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='SEDwebsite_http_virtualhost_fileSED' 
WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDwebsite_https_virtualhost_fileSED' 
WEBSITE_HTTP_PORT='SEDwebsite_http_portSED'
WEBSITE_HTTPS_PORT='SEDwebsite_https_portSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
admin_log_file='/var/log/admin_website_delete.log'

# Check if Apache and SSL is installed.
apache_installed='false'
ssl_enabled='false'

if [[ -f "${APACHE_INSTALL_DIR}"/conf/httpd.conf ]]
then
   apache_installed='true'
fi

if [[ -f "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf ]]
then
   ssl_enabled='true'
fi

echo "SSL enabled ${ssl_enabled}." >> "${admin_log_file}"
exit
#
# Apache virtualhosts.
#

rm -f "${APACHE_SITES_ENABLED_DIR:?}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE:?}" 
rm -f "${APACHE_SITES_ENABLED_DIR:?}"/"${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE:?}" 

echo 'Admin website virtualhosts disabled.' >> "${admin_log_file}" 2>&1

#
# Apache ports.
#

if [[ 'true' == "${apache_installed}" ]]
then
   echo 'Found Apache installed.' >> "${admin_log_file}" 2>&1
   
   sed -i "s/^Listen \+${WEBSITE_HTTP_PORT}/#Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

   echo "Apache web server disabled listen on ${WEBSITE_HTTP_PORT} port." >> "${admin_log_file}" 2>&1
fi

if [[ 'true' == "${ssl_enabled}" ]]
then
   echo 'Found Apache SSL enalbled.' >> "${admin_log_file}" 2>&1
   
   sed -i "s/^Listen \+${WEBSITE_HTTPS_PORT}/#Listen ${WEBSITE_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf

   echo "Apache web server disabled listen on ${WEBSITE_HTTPS_PORT} port." >> "${admin_log_file}" 2>&1
fi

#
# Website sources.
#

website_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"
rm -rf "${website_dir:?}"

echo 'Admin website sources deleted.' >> "${admin_log_file}" 2>&1

httpd -t >> "${admin_log_file}" 2>&1
systemctl restart httpd >> "${admin_log_file}" 2>&1

echo 'Apache web server restarted.' >> "${admin_log_file}" 2>&1

exit 0

