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
webphp_log_file='/var/log/website_install.log'

echo 'Deleting WebPhp website ...' >> "${webphp_log_file}" 2>&1

cd "${script_dir}" || exit

# Disable the WebPhp site.
rm -f "${APACHE_SITES_ENABLED_DIR:?}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE:?}" 
echo 'WebPhp website virtualhost disabled' >> "${webphp_log_file}" 2>&1

# Delete WebPhp website
webphp_domain_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"
rm -rf "${webphp_domain_dir:?}"
echo 'Removed WebPhp website' >> "${webphp_log_file}" 2>&1

echo 'WebPhp website Deleted' >> "${webphp_log_file}" 2>&1
echo 'Reboot the server' >> "${webphp_log_file}" 2>&1

exit 194

