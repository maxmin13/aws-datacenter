#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## Install Apache Web Server mod_security web application firewall.
##
## Files to upload:
## 1) owasp_mod_security.conf
## 2) modsecurity_overrides.conf
## 3) owasp-coreruleset.tar.gz

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
OWASP_ARCHIVE='SEDowasp_archiveSED'

yum install mod_security -y

rm -rf "${APACHE_INSTALL_DIR:?}"/modsecurity.d
mkdir -p "${APACHE_INSTALL_DIR}"/modsecurity.d

cd "${script_dir}" || exit

# Customize ModSecurity by choosing the rule set from OWASP CRS.
mkdir owasp-modsecurity-crs
tar -xvf "${OWASP_ARCHIVE}" --directory owasp-modsecurity-crs --strip-components 1 
cd owasp-modsecurity-crs || exit
mv crs-setup.conf.example crs-setup.conf
mv rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
mv rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf

cd "${script_dir}" || exit

mv owasp-modsecurity-crs "${APACHE_INSTALL_DIR}"/modsecurity.d
mv owasp_mod_security.conf "${APACHE_INSTALL_DIR}"/conf.d 
echo 'Apache Web Server Owasp rules configured'

mv modsecurity_overrides.conf "${APACHE_INSTALL_DIR}"/modsecurity.d/
echo 'Apache Web Server Security overrides configured'

# Set files and directories permissions
find "${APACHE_INSTALL_DIR}/modsecurity.d" -type d -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}/modsecurity.d" -type d -exec chmod 500 {} +
find "${APACHE_INSTALL_DIR}/modsecurity.d" -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}/modsecurity.d" -type f -exec chmod 400 {} +
find "${APACHE_INSTALL_DIR}/conf.d" -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}/conf.d" -type f -exec chmod 400 {} +

# Check the syntax of configuration files.
httpd -t
systemctl restart httpd
echo 'Apache Security module installed'

echo '-------------------------------------------------'
echo 'Directory modules:'
ls -lh "${APACHE_INSTALL_DIR}"/modules
echo '-------------------------------------------------'
echo 'Modules compiled statically into the server:'
/usr/sbin/httpd -l
echo '-------------------------------------------------'
echo 'Modules compiled dynamically enabled with Apache'
/usr/sbin/httpd -M
echo '-------------------------------------------------'
echo 'Server version:'
/usr/sbin/httpd -V
echo '-------------------------------------------------'

exit 0
