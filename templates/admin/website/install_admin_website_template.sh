#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='SEDwebsite_http_virtualhost_fileSED' 
WEBSITE_HTTP_PORT='SEDwebsite_http_portSED'
WEBSITE_ARCHIVE='SEDwebsite_archiveSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
admin_log_file='/var/log/admin_website_install.log'

#
# Website sources.
#

cd "${script_dir}" || exit
mkdir admin
unzip "${WEBSITE_ARCHIVE}" -d admin  >> "${admin_log_file}"
website_docroot="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"/public_html
mkdir --parents "${website_docroot}"
rsync -avq --delete admin/* "${website_docroot}"
rm -rf admin

echo 'Admin sources installed' >> "${admin_log_file}"

find "${website_docroot}" -type d -exec chown root:root {} +
find "${website_docroot}" -type d -exec chmod 755 {} +
find "${website_docroot}" -type f -exec chown root:root {} +
find "${website_docroot}" -type f -exec chmod 644 {} +

#
# Apache virtualhost.
#

cd "${script_dir}" || exit
cp -f "${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" ]]
then
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Admin virtualhost enabled' >> "${admin_log_file}"
fi

#
# Apache HTTP port.
#

sed -i "s/^#Listen \+${WEBSITE_HTTP_PORT}/Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo "Apache web server listen on ${WEBSITE_HTTP_PORT} port."

httpd -t
systemctl restart httpd >> "${admin_log_file}" 2>&1

echo 'Apache web server restarted' >> "${admin_log_file}" 2>&1

exit 0

