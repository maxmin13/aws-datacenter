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
WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE='SEDwebsite_https_virtualhost_fileSED'
WEBSITE_HTTP_PORT='SEDwebsite_http_portSED'
WEBSITE_HTTPS_PORT='SEDwebsite_https_portSED'
WEBSITE_ARCHIVE='SEDwebsite_archiveSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
admin_log_file='/var/log/admin_website_install.log'

cd "${script_dir}" || exit

### TODO pass SEDadmin_inst_user_nmSED value
# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

# Check if SSL is installed.
ssl_enabled='false'

if [[ -f "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf ]]
then
   ssl_enabled='true'
fi

echo "SSL enabled ${ssl_enabled}." >> "${admin_log_file}"

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

echo 'Admin sources installed.' >> "${admin_log_file}"

find "${website_docroot}" -type d -exec chown root:root {} +
find "${website_docroot}" -type d -exec chmod 755 {} +
find "${website_docroot}" -type f -exec chown root:root {} +
find "${website_docroot}" -type f -exec chmod 644 {} +

#
# Apache virtualhosts.
#

http_virhost="${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}"
https_virhost="${WEBSITE_HTTPS_VIRTUALHOST_CONFIG_FILE}"

cd "${script_dir}" || exit
cp -f "${http_virhost}" "${APACHE_SITES_AVAILABLE_DIR}"
cp -f "${https_virhost}" "${APACHE_SITES_AVAILABLE_DIR}"

rm -f "${APACHE_SITES_ENABLED_DIR}"/"${https_virhost}"
rm -f "${APACHE_SITES_ENABLED_DIR}"/"${http_virhost}"

if [[ 'true' == "${ssl_enabled}" ]]
then
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${https_virhost}" "${APACHE_SITES_ENABLED_DIR}"/"${https_virhost}"
   
   echo 'Admin HTTPS virtualhost enabled.' >> "${admin_log_file}"
else
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${http_virhost}" "${APACHE_SITES_ENABLED_DIR}"/"${http_virhost}"
   
   echo 'Admin HTTP virtualhost enabled.' >> "${admin_log_file}"
fi

#
# Apache ports.
#

if [[ 'true' == "${ssl_enabled}" ]]
then
   sed -i "s/^#Listen \+${WEBSITE_HTTPS_PORT}/Listen ${WEBSITE_HTTPS_PORT}/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
   sed -i "s/^Listen \+${WEBSITE_HTTP_PORT}$/#Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

   echo "Apache web server listen on ${WEBSITE_HTTPS_PORT} port." >> "${admin_log_file}" 2>&1
else
   sed -i "s/^#Listen \+${WEBSITE_HTTP_PORT}$/Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

   echo "Apache web server listen on ${WEBSITE_HTTP_PORT} port." >> "${admin_log_file}" 2>&1
fi

httpd -t >> "${admin_log_file}" 2>&1
systemctl restart httpd >> "${admin_log_file}" 2>&1

echo 'Apache web server restarted.' >> "${admin_log_file}" 2>&1

exit 0

