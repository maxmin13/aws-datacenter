#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='SEDwebsite_http_virtualhost_configSED'
WEBSITE_HTTP_PORT='SEDwebsite_http_portSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
webphp_log_file='/var/log/webphp_website_delete.log'

echo 'Removing Webphp website ...' >> "${webphp_log_file}" 2>&1

#
# Apache HTTP port.
#

sed -i "s/^Listen \+${WEBSITE_HTTP_PORT}/#Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo "Disabled Apache listen on port ${WEBSITE_HTTP_PORT}."

#
# Apache virtualhost.
#

rm -f "${APACHE_SITES_ENABLED_DIR:?}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE:?}" 

echo 'Webphp website virtualhost disabled.' >> "${webphp_log_file}" 2>&1

#
# Website sources.
#

webphp_domain_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"
rm -rf "${webphp_domain_dir:?}"

echo 'Webphp sources deleted.' >> "${webphp_log_file}" 2>&1

httpd -t >> "${webphp_log_file}" 2>&1
systemctl restart httpd >> "${webphp_log_file}" 2>&1

echo 'Apache web server restarted.' >> "${webphp_log_file}" 2>&1
echo 'Webphp website removed.'

exit 0

