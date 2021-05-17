#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_VIRTUALHOST_CONFIG_FILE='SEDwebsite_virtualhost_fileSED' 
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
admin_log_file='/var/log/admin_website_install.log'

echo 'Deleting Admin website ...' >> "${admin_log_file}" 2>&1

cd "${script_dir}" || exit

# Disable the admin site.
rm -f "${APACHE_SITES_ENABLED_DIR:?}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE:?}" 
echo 'Admin Web Site virtualhost disabled' >> "${admin_log_file}"

# Delete the Admin website
website_domain_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"
rm -rf "${website_domain_dir:?}"
echo 'Removed Admin website' >> "${admin_log_file}"

echo 'Admin Web Site deleted' >> "${admin_log_file}" 2>&1
echo 'Reboot the server' >> "${admin_log_file}"

exit 194

