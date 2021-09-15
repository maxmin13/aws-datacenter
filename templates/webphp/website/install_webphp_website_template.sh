#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
WEBSITE_ARCHIVE='SEDwebsite_archiveSED'
WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE='SEDwebphp_virtual_host_configSED'
WEBSITE_HTTP_PORT='SEDwebsite_http_portSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBPHP_INST_USER_NM='SEDwebphp_inst_user_nmSED'
webphp_log_file='/var/log/website_install.log'

#
# Website sources.
#

trap 'chown -R ${WEBPHP_INST_USER_NM}:${WEBPHP_INST_USER_NM} ${script_dir}' ERR EXIT

cd "${script_dir}" || exit

mkdir webphp
unzip "${WEBSITE_ARCHIVE}" -d webphp >> "${webphp_log_file}" 2>&1
webphp_docroot="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"/public_html
mkdir --parents "${webphp_docroot}"
rsync -avq --delete webphp/* "${webphp_docroot}"
rm -rf webphp/

## Move phpinclude directory outside of the public area
cd "${webphp_docroot}"
rsync -avq phpinclude ../

## Update the paths in the pages
find . -type f  -print0 | xargs -0 sed -i 's/\.\.\/phpinclude/\.\.\/\.\.\/phpinclude/g'
sed -i "s/phpinclude/..\/phpinclude/g" index.php

echo 'Webphp site installed' >> "${webphp_log_file}" 2>&1

# TODO see how to run apache with suexec unique user
find "${webphp_docroot}" -type d -exec chown root:root {} +
find "${webphp_docroot}" -type d -exec chmod 755 {} +
find "${webphp_docroot}" -type f -exec chown root:root {} +
find "${webphp_docroot}" -type f -exec chmod 644 {} +

#
# Apache virtualhost.
#

cd "${script_dir}" || exit
cp -f "${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" ]]
then
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_HTTP_VIRTUALHOST_CONFIG_FILE}"
   
   echo 'Webphp virtualhost enabled' >> "${webphp_log_file}"
fi

#
# Apache HTTP port.
#

sed -i "s/^#Listen \+${WEBSITE_HTTP_PORT}/Listen ${WEBSITE_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo "Apache web server listen on ${WEBSITE_HTTP_PORT} port."

httpd -t >> "${webphp_log_file}" 2>&1
systemctl restart httpd >> "${webphp_log_file}" 2>&1

echo 'Apache web server restarted' >> "${webphp_log_file}" 2>&1

exit 0

