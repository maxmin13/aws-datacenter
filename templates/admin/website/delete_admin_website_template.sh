#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='SEDwebsite_http_virtualhost_fileSED' 
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
admin_log_file='/var/log/admin_website_install.log'

echo 'Deleting Admin website ...' >> "${admin_log_file}" 2>&1

cd "${script_dir}" || exit

# Disable Apache listen on port 80
sed -i "s/Listen 80/#SEDlisten_port_80SED/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

# Disable the Admin virtual host.
rm -f "${APACHE_SITES_ENABLED_DIR:?}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE:?}" 
echo 'Admin Web Site virtualhost disabled' >> "${admin_log_file}"

# Delete the Admin website
website_domain_dir="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"
rm -rf "${website_domain_dir:?}"
echo 'Removed Admin website' >> "${admin_log_file}"

systemctl restart httpd >> "${admin_log_file}" 2>&1

echo 'Apache web server restarted' >> "${admin_log_file}" 2>&1

exit 0

