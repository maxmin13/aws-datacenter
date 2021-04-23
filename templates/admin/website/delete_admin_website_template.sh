#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_DOC_ROOT_DIR='SEDapache_doc_root_dirSED'
SERVER_ADMIN_SITE_DOMAIN_NM='SEDadmin_domain_nameSED'
admin_log_file='/var/log/admin_remove_website.log'

# Delete Admin website, but not phpmyadmin or loganalyzer
admin_doc_root="${APACHE_DOC_ROOT_DIR}"/"${SERVER_ADMIN_SITE_DOMAIN_NM}"/public_html

rm -rf "${admin_doc_root}"
echo 'Removed Admin Web Site'

## TODO
# Disable the admin site.
cd /home/ec2-user || exit
cp -f public.virtualhost.maxmin.it.conf "${APACHE_SITES_AVAILABLE_DIR}"
echo 'Admin Web Site virtualhost disabled'

echo 'Reboot the server'

exit 194

