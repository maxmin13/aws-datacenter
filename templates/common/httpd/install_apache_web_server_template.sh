#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## Install Apache Web Server on /etc/httpd directory,
## Listen on 80 port, no SSL.
## Files required to be uploaded:
## 1) httpd.conf 
## 2) httpd-mpm.conf 

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_DOC_ROOT_DIR='SEDapache_doc_root_dirSED'
APACHE_JAIL_DIR='SEDapache_jail_dirSED'
## APACHE_USR='SEDapache_usrSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'

# TODO see how to run apache with suexec unique user
#if ! getent group |grep -q "${APACHE_USR}"
#then
   ## Creating the apache user and group
#   groupadd "${APACHE_USR}"
#   useradd -s /bin/false -M -g "${APACHE_USR}" "${APACHE_USR}"
#   echo 'User apache created'
#fi

echo 'Installing Apache Web Server ...'
yum install -y httpd
systemctl enable httpd.service
echo 'Apache Web Server installed'

# Clear directories and configuration files.
cd /var/www || exit
rm -f -R cgi-bin error icons
mkdir -p "${APACHE_SITES_AVAILABLE_DIR}" "${APACHE_SITES_ENABLED_DIR}"
mkdir "${APACHE_JAIL_DIR}"

# Configuration files 
cd /home/ec2-user || exit
mv "${APACHE_INSTALL_DIR}"/conf/httpd.conf "${APACHE_INSTALL_DIR}"/conf/httpd.conf.back
cp -f httpd.conf "${APACHE_INSTALL_DIR}"/conf
cp /etc/mime.types "${APACHE_INSTALL_DIR}"/conf
cp httpd-mpm.conf "${APACHE_INSTALL_DIR}"/conf.d

# Files and directories permissions
chown root:root "${APACHE_JAIL_DIR}"
find "${APACHE_INSTALL_DIR}"/conf -type d -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf -type d -exec chmod 500 {} +
find "${APACHE_INSTALL_DIR}"/conf -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf -type f -exec chmod 400 {} +
find "${APACHE_INSTALL_DIR}"/conf.d -type d -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.d -type d -exec chmod 500 {} +
find "${APACHE_INSTALL_DIR}"/conf.d -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.d -type f -exec chmod 400 {} +
find "${APACHE_INSTALL_DIR}"/conf.modules.d -type d -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.modules.d -type d -exec chmod 500 {} +
find "${APACHE_INSTALL_DIR}"/conf.modules.d -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.modules.d -type f -exec chmod 400 {} +

## Set webroot permissions, each application will be run underneeth this level,
## eg: /var/www/html/admin.maxmin.it/public_html/admin/
# TODO see how to run apache with suexec unique user
find "${APACHE_DOC_ROOT_DIR}" -type d -exec chown root:root {} +
find "${APACHE_DOC_ROOT_DIR}" -type d -exec chmod 755 {} +
find "${APACHE_DOC_ROOT_DIR}" -type f -exec chown root:root {} +
find "${APACHE_DOC_ROOT_DIR}" -type f -exec chmod 400 {} +

# Check the syntax
httpd -t

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


