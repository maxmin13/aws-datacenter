#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'
WEBSITE_ARCHIVE='SEDwebsite_archiveSED'
WEBSITE_VIRTUALHOST_CONFIG_FILE='SEDwebphp_virtual_host_configSED'
webphp_log_file='/var/log/website_install.log'

cd /home/ec2-user || exit
mkdir webphp
unzip "${WEBSITE_ARCHIVE}" -d webphp >> "${webphp_log_file}" 2>&1
webphp_docroot="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"/public_html
mkdir --parents "${webphp_docroot}"
mv webphp/* "${webphp_docroot}"

## Move phpinclude directory outside of the public area
cd "${webphp_docroot}"
mv phpinclude ../

## Update the paths in the pages
sed -i "s/\/phpinclude/..\/phpinclude/g" index.php
cd account
find . -type f  -print0 | xargs -0 sed -i "s/..\/phpinclude/..\/..\/phpinclude/g"
cd ../public
find . -type f  -print0 | xargs -0 sed -i "s/..\/phpinclude/..\/..\/phpinclude/g"
cd ../sns
find . -type f  -print0 | xargs -0 sed -i "s/..\/phpinclude/..\/..\/phpinclude/g"

echo 'WebPhp site installed' >> "${webphp_log_file}" 2>&1

# TODO see how to run apache with suexec unique user
find "${webphp_docroot}" -type d -exec chown root:root {} +
find "${webphp_docroot}" -type d -exec chmod 755 {} +
find "${webphp_docroot}" -type f -exec chown root:root {} +
find "${webphp_docroot}" -type f -exec chmod 644 {} +

# Enable the WebPhp site.
cd /home/ec2-user || exit
cp -f "${WEBSITE_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"
ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}" 
echo 'WebPhp site enabled' >> "${webphp_log_file}" 2>&1

echo 'Reboot the server' >> "${webphp_log_file}" 2>&1

exit 194

