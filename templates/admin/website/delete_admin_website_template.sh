#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_VIRTUALHOST_CONFIG_FILE='SEDwebsite_virtualhost_fileSED' 
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
admin_log_file='/var/log/admin_install.log'

# Disable the admin site.
cd /home/ec2-user || exit
rm -f "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}" 
echo 'Admin Web Site virtualhost disabled' >> "${admin_log_file}"

# Delete the Admin website
website_domain_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"
rm -rf "${website_domain_dir:?}"
echo 'Removed Admin Web Site' >> "${admin_log_file}"

echo 'Reboot the server' >> "${admin_log_file}"

exit 194

