#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

ENV='SEDenvironmentSED'
SRV_ADMIN_HOSTNAME='SEDserver_admin_hostnameSED'
APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
MMONIT_ARCHIVE='SEDmmonit_archiveSED'
MMONIT_DIR='SEDmmonit_install_dirSED'
MONIT_DOCROOT_ID='SEDmonit_docroot_idSED'
MONIT_HTTP_VIRTUALHOST_CONFIG_FILE='SEDmonit_http_virtualhost_fileSED'
PHPMYADMIN_DOCROOT_ID='SEDphpmyadmin_docroot_idSED'
PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE='SEDphpmyadmin_http_virtualhost_fileSED'
LOGANALYZER_ARCHIVE='SEDloganalyzer_archiveSED'
LOGANALYZER_DOCROOT_ID='SEDloganalyzer_docroot_idSED'
LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE='SEDloganalyzer_http_virtualhost_fileSED'

admin_log_file='/var/log/admin_install.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

amazon-linux-extras install epel -y >> "${admin_log_file}" 2>&1

## 
## Rsyslog 
## 

cd "${script_dir}" || exit

cp -f /etc/rsyslog.conf /etc/rsyslog.conf__backup
cp -f rsyslog.conf /etc/rsyslog.conf
chown root:root /etc/rsyslog.conf
chmod 400 /etc/rsyslog.conf

find '/var/log' -type d -exec chown root:root {} +
find '/var/log' -type d -exec chmod 755 {} +
find '/var/log' -type f -exec chown root:root {} +
find '/var/log' -type f -exec chmod 644 {} +

echo 'Rsyslog configured.'

## 
## Apache Web Server 
## 

cd "${script_dir}" || exit

echo 'Installing Apache Web Server ...'

chmod +x install_apache_web_server.sh 
./install_apache_web_server.sh >> "${admin_log_file}" 2>&1

echo 'Apache Web Server installed.'

##
## PHP 
## 

cd "${script_dir}" || exit

echo 'Installing PHP ...'

chmod +x install_php.sh 
./install_php.sh >> "${admin_log_file}" 2>&1

echo 'PHP installed.'

## 
## Apache FastCGI module 
##

cd "${script_dir}" || exit

echo 'Extending Apache Web Server with FastCGI ...'

chmod +x extend_apache_web_server_with_FCGI.sh 
./extend_apache_web_server_with_FCGI.sh >> "${admin_log_file}" 2>&1

echo 'Apache Web Server extended with FastCGI.'

## 
## M/Monit 
## 

cd "${script_dir}" || exit

echo 'Installing M/Monit ...'

rm -rf "${MMONIT_DIR:?}"
mkdir "${MMONIT_DIR}"
tar -xvf "${MMONIT_ARCHIVE}" --directory "${MMONIT_DIR}" --strip-components 1 >> "${admin_log_file}" 2>&1
cp -f server.xml "${MMONIT_DIR}"/conf/server.xml
chown root:root "${MMONIT_DIR}"/conf/server.xml
chmod 400 "${MMONIT_DIR}"/conf/server.xml

cd "${script_dir}" || exit

## Install M/Monit as a systemd service
cp -f mmonit.service /etc/systemd/system
chown root:root /etc/systemd/system/mmonit.service
chmod 400 /etc/systemd/system/mmonit.service

echo 'M/Monit installed.'

## 
## PHPMyAdmin 
## 

cd "${script_dir}" || exit

echo 'Installing PHPMyAdmin ...'

yum install -y phpmyadmin >> "${admin_log_file}" 2>&1 

echo 'PHPMyAdmin installed.'

phpMyAdmin_docroot="${APACHE_DOCROOT_DIR}"/"${PHPMYADMIN_DOCROOT_ID}"/public_html
mkdir --parents "${phpMyAdmin_docroot}"

if [[ -d /usr/share/phpMyAdmin ]]
then
   mv /usr/share/phpMyAdmin "${phpMyAdmin_docroot}"/phpmyadmin
   
   echo 'Phpmyadmin moved under Apache.'
fi

rm -f /etc/httpd/conf.d/phpMyAdmin.conf
cp -f config.inc.php /etc/phpMyAdmin/config.inc.php

# Configuration files permissions
chown root:root /etc/phpMyAdmin/config.inc.php
chmod 644 /etc/phpMyAdmin/config.inc.php
chown root:root /etc/phpMyAdmin
chmod 755 /etc/phpMyAdmin/

# Public pages permissions.
find "${phpMyAdmin_docroot}"/phpmyadmin -type d -exec chown root:root {} +
find "${phpMyAdmin_docroot}"/phpmyadmin -type d -exec chmod 755 {} +
find "${phpMyAdmin_docroot}"/phpmyadmin -type f -exec chown root:root {} +
find "${phpMyAdmin_docroot}"/phpmyadmin -type f -exec chmod 644 {} +

cd "${script_dir}" || exit

# Enable the and phpmyadmin site.
cp "${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" ]]
then
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${PHPMYADMIN_HTTP_VIRTUALHOST_CONFIG_FILE}"
fi

echo 'Phpmyadmin installed.'

## 
## Loganalyzer 
## 

cd "${script_dir}" || exit

echo 'Installing Loganalyzer ...'

rm -rf loganalyzer
mkdir loganalyzer
tar -xvf "${LOGANALYZER_ARCHIVE}" --directory loganalyzer --strip-components 1 >> "${admin_log_file}" 2>&1 && cd loganalyzer || exit  
loganalyzer_docroot="${APACHE_DOCROOT_DIR}"/"${LOGANALYZER_DOCROOT_ID}"/public_html
mkdir --parents "${loganalyzer_docroot}"
cp -rf src "${loganalyzer_docroot}"/loganalyzer

cd "${script_dir}" || exit
cp config.php "${loganalyzer_docroot}"/loganalyzer

# Public pages permissions.
find "${loganalyzer_docroot}"/loganalyzer -type d -exec chown root:root {} +
find "${loganalyzer_docroot}"/loganalyzer -type d -exec chmod 755 {} +
find "${loganalyzer_docroot}"/loganalyzer -type f -exec chown root:root {} +
find "${loganalyzer_docroot}"/loganalyzer -type f -exec chmod 644 {} +

cd "${script_dir}" || exit

cp "${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" ]]
then
   # Enable the and Loganalyzer site.  
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${LOGANALYZER_HTTP_VIRTUALHOST_CONFIG_FILE}"
fi

rm -rf loganalyzer

echo 'Loganalyzer installed.'

##
## Monit 
## 

# Monit handles start/stop of other services.

cd "${script_dir}" || exit

echo 'Installing Monit ...'

yum install -y monit >> "${admin_log_file}" 2>&1 
cp -f monitrc /etc/monitrc

{
   systemctl disable chronyd.service 
   systemctl disable sshd.service 
   systemctl disable mmonit.service
   systemctl disable httpd.service
   systemctl disable php-fpm
   systemctl enable monit.service
   systemctl start monit.service
} >> "${admin_log_file}" 2>&1

rm -f /etc/monit.d/logging

echo 'Monit installed.'

# Create an Apache Web Server heartbeat endpoint, see monitrc configuration file.
monit_docroot="${APACHE_DOCROOT_DIR}"/"${MONIT_DOCROOT_ID}"/public_html
mkdir --parents "${monit_docroot}"
touch "${monit_docroot}"/monit
echo ok > "${monit_docroot}"/monit

cd "${script_dir}" || exit

# Enable the Monit site (Apache Web Server heartbeat).
cp "${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}" 

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" ]]
then
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${MONIT_HTTP_VIRTUALHOST_CONFIG_FILE}" 
fi

echo 'Monit installed.'

## 
## PHP sched files 
## 

# line="1 0,6,12,18 * * * wget --no-check-certificate -O - -q https://localhost/sched/ataglance.php | /usr/bin/logger -t ataglance -p local6.info"
# (crontab -u root -l; echo "$line" ) | crontab -u root -
# echo php scheduled files crontabbed

##
## SSH config
##

cd "${script_dir}" || exit
cp sshd_config /etc/ssh/sshd_config
chown root:root /etc/ssh/sshd_config
chmod 400 /etc/ssh/sshd_config

echo 'SSH configured.'

## 
## Logrotate 
##

# cd "${script_dir}" || exit
# cp -f logrotatehttp /etc/logrotate.d/logrotatehttp
# chown root:root /etc/logrotate.d/logrotatehttp
# chmod 644 /etc/logrotate.d/logrotatehttp
# mkdir -p /var/log/old
# chown root:root /var/log/old
# chmod 700 /var/log/old

## 
## JavaMail 
## 

# cd "${script_dir}" || exit
# mkdir /java
# mkdir /java/javamail
# cp -f launch_javaMail.sh /java/javamail/launch_javaMail.sh

# chown root:root /java
# chmod 700 /java
# find /java -type d -exec chown root:root {} +
# find /java -type d -exec chmod 700 {} +
# find /java -type f -exec chown root:root {} +
# find /java -type f -exec chmod 700 {} +

amazon-linux-extras disable epel -y >> "${admin_log_file}" 2>&1

echo 'Reboot the server.'

exit 194



