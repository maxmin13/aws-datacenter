#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
PUBLIC_VIRTUALHOST_CONFIG_FILE='SEDvirtual_host_configSED'
APACHE_DOC_ROOT_DIR='SEDapache_doc_root_dirSED'
APACHE_JAIL_DIR='SEDapache_jail_dirSED'
SERVER_WEBPHP_SITE_DOMAIN_NM='SEDwebphp_domain_nameSED'
webphp_log_file='/var/log/webphp_install_website.log'

# Delete WebPhp website
webphp_domain_dir="${APACHE_JAIL_DIR}"/"${APACHE_DOC_ROOT_DIR}"/"${SERVER_WEBPHP_SITE_DOMAIN_NM}"
rm -rf "${webphp_domain_dir}"
echo 'Removed WebPhp Web Site'

## TODO
# Disable the WebPhp site.
cd /home/ec2-user || exit
cp -f "${PUBLIC_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"
echo 'WebPhp Web Site virtualhost disabled'

echo 'Reboot the server'

exit 194

