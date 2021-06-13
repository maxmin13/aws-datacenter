#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_VIRTUALHOST_CONFIG_FILE='SEDvirtualhost_configSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
webphp_log_file='/var/log/website_remove.log'

echo 'Deleting Webphp website ...' >> "${webphp_log_file}" 2>&1

cd "${script_dir}" || exit

# Disable the WebPhp site.
rm -f "${APACHE_SITES_ENABLED_DIR:?}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE:?}" 

echo 'Webphp website virtualhost disabled' >> "${webphp_log_file}" 2>&1

# Delete WebPhp website
webphp_domain_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"
rm -rf "${webphp_domain_dir:?}"

echo 'Deleted website' >> "${webphp_log_file}" 2>&1

systemctl restart httpd >> "${webphp_log_file}" 2>&1

echo 'Apache web server restarted.' >> "${webphp_log_file}" 2>&1
echo 'Webphp website removed.'

exit 0

