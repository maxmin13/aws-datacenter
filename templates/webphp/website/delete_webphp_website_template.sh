#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_VIRTUALHOST_CONFIG_FILE='SEDvirtualhost_configSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
webphp_log_file='/var/log/website_install.log'

# Disable the WebPhp site.
cd /home/ec2-user || exit
rm -f "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}" 
echo 'WebPhp Web Site virtualhost disabled' >> "${webphp_log_file}" 2>&1

# Delete WebPhp website
webphp_domain_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"
rm -rf "${webphp_domain_dir:?}"
echo 'Removed WebPhp Web Site' >> "${webphp_log_file}" 2>&1

echo 'Reboot the server' >> "${webphp_log_file}" 2>&1

exit 194

