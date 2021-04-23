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
PHPINCLUDE_ARCHIVE='SEDphpinclude_achiveSED'
HTDOCS_ARCHIVE='SEDhtdocs_archiveSED'
webphp_log_file='/var/log/webphp_install_website.log'

cd /home/ec2-user || exit
mkdir webphp
unzip "${HTDOCS_ARCHIVE}" -d webphp
webphp_doc_root="${APACHE_JAIL_DIR}"/"${APACHE_DOC_ROOT_DIR}"/"${SERVER_WEBPHP_SITE_DOMAIN_NM}"/public_html
mkdir --parents "${webphp_doc_root}"
mv webphp "${webphp_doc_root}"

mkdir phpinclude
unzip "${PHPINCLUDE_ARCHIVE}" -d phpinclude
# Move the files outside of the public area
webphp_domain_dir="${APACHE_JAIL_DIR}"/"${APACHE_DOC_ROOT_DIR}"/"${SERVER_WEBPHP_SITE_DOMAIN_NM}"
mv phpinclude "${webphp_domain_dir}"

echo 'WebPhp site installed'

# TODO see how to run apache with suexec unique user
find "${webphp_doc_root}"/webphp -type d -exec chown root:root {} +
find "${webphp_doc_root}"/webphp -type d -exec chmod 755 {} +
find "${webphp_doc_root}"/webphp -type f -exec chown root:root {} +
find "${webphp_doc_root}"/webphp -type f -exec chmod 644 {} +
find "${webphp_domain_dir}"/phpinclude -type d -exec chown root:root {} +
find "${webphp_domain_dir}"/phpinclude -type d -exec chmod 755 {} +
find "${webphp_domain_dir}"/phpinclude -type f -exec chown root:root {} +
find "${webphp_domain_dir}"/phpinclude -type f -exec chmod 644 {} +

# Enable the WebPhp site.
cd /home/ec2-user || exit
cp -f "${PUBLIC_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"
echo 'WebPhp site enabled'

echo 'Reboot the server'

exit 194

