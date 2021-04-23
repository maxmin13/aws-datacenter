#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
PUBLIC_VIRTUALHOST_CONFIG_FILE='SEDvirtual_host_configSED'
ADMIN_SITE_ARCHIVE='SEDadmin_archiveSED'
APACHE_DOC_ROOT_DIR='SEDapache_doc_root_dirSED'
SERVER_ADMIN_SITE_DOMAIN_NM='SEDadmin_domain_nameSED'
admin_log_file='/var/log/admin_install_website.log'

cd /home/ec2-user || exit
mkdir admin
unzip "${ADMIN_SITE_ARCHIVE}" -d admin
admin_doc_root="${APACHE_DOC_ROOT_DIR}"/"${SERVER_ADMIN_SITE_DOMAIN_NM}"/public_html
mkdir --parents "${admin_doc_root}"
mv admin "${admin_doc_root}"
echo 'Admin site installed'

# TODO see how to run apache with suexec unique user
find "${admin_doc_root}"/admin -type d -exec chown root:root {} +
find "${admin_doc_root}"/admin -type d -exec chmod 755 {} +
find "${admin_doc_root}"/admin -type f -exec chown root:root {} +
find "${admin_doc_root}"/admin -type f -exec chmod 644 {} +

# Enable the Admin site.
cd /home/ec2-user || exit
cp -f "${PUBLIC_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"
echo 'Admin site enabled'

echo 'Reboot the server'

exit 194

