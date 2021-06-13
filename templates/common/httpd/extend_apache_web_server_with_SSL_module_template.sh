#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## Install Apache Web Server SSL module and generate a primary-key and a certificate,
## Listen on 80 port, no SSL.
##
## Dependencies:
## ssl.conf
## 00-ssl.conf

ENV='SEDenvironmentSED'
APACHE_INSTALL_DIR='SEDapache_install_dirSED'
#APACHE_USR='SEDapache_usrSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Extending Apache web server with SSL module ...'

yum install -y mod_ssl

mkdir -p "${APACHE_INSTALL_DIR}"/ssl

cd "${script_dir}" || exit

cp ssl.conf "${APACHE_INSTALL_DIR}"/conf.d
cp 00-ssl.conf "${APACHE_INSTALL_DIR}"/conf.modules.d

# Set files and directories permissions

find "${APACHE_INSTALL_DIR}"/conf.d -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.d -type f -exec chmod 400 {} +
find "${APACHE_INSTALL_DIR}"/conf.modules.d -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.modules.d -type f -exec chmod 400 {} +

# Check the syntax of configuration files.
httpd -t
echo 'Apache SSL module installed'

systemctl restart httpd

echo 'Apache web server restarted'

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


