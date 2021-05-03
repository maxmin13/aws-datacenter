#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
WEBSITE_VIRTUALHOST_CONFIG_FILE='SEDwebsite_virtualhost_fileSED' 
WEBSITE_ARCHIVE='SEDwebsite_archiveSED'
WEBSITE_DOCROOT_ID='SEDwebsite_docroot_idSED'

cd /home/ec2-user || exit
mkdir admin
unzip "${WEBSITE_ARCHIVE}" -d admin
website_doc_root="${APACHE_DOCROOT_DIR}"/"${WEBSITE_DOCROOT_ID}"/public_html
mkdir --parents "${website_doc_root}"
mv admin "${website_doc_root}"
echo 'Admin site installed'

find "${website_doc_root}"/admin -type d -exec chown root:root {} +
find "${website_doc_root}"/admin -type d -exec chmod 755 {} +
find "${website_doc_root}"/admin -type f -exec chown root:root {} +
find "${website_doc_root}"/admin -type f -exec chmod 644 {} +

# Enable the Admin site.
cd /home/ec2-user || exit
cp -f "${WEBSITE_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"
ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}"
echo 'Admin site enabled'

echo 'Reboot the server'

exit 194

