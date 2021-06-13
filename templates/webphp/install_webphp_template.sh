#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Install a Linux Apache PHP server (LAP).

ENV='SEDenvironmentSED'
SRV_WEBPHP_HOSTNAME='SEDserver_webphp_hostnameSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
LOADBALANCER_VIRTUALHOST_CONFIG_FILE='SEDloadbalancer_virtualhost_configSED'
LOADBALANCER_DOCROOT_ID='SEDloadbalancer_docroot_idSED'
MONIT_VIRTUALHOST_CONFIG_FILE='SEDmonit_virtualhost_configSED'
MONIT_DOCROOT_ID='SEDmonit_docroot_idSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
webphp_log_file='/var/log/website_install.log'

amazon-linux-extras install epel -y >> "${webphp_log_file}" 2>&1

## *************** ##
## System hostname ##
## *************** ##

hostnamectl set-hostname "${SRV_WEBPHP_HOSTNAME}"
echo 'System hostname modified:'
hostname

## ******* ##
## Rsyslog ##
## ******* ##

cd "${script_dir}" || exit

cp -f /etc/rsyslog.conf /etc/rsyslog.conf__backup
cp -f rsyslog.conf /etc/rsyslog.conf

chown root:root /etc/rsyslog.conf
chmod 400 /etc/rsyslog.conf

find '/var/log' -type d -exec chown root:root {} +
find '/var/log' -type d -exec chmod 755 {} +
find '/var/log' -type f -exec chown root:root {} +
find '/var/log' -type f -exec chmod 644 {} +

echo 'Rsyslog configured'

## ***************** ##
## Apache Web Server ##
## ***************** ##

cd "${script_dir}" || exit

echo 'Installing Apache Web Server ...'
chmod +x install_apache_web_server.sh 
./install_apache_web_server.sh >> "${webphp_log_file}" 2>&1
echo 'Apache Web Server installed'

## *************** ##
## Security Module ##
## *************** ##

cd "${script_dir}" || exit

echo 'Installing Apache Web Server Security module ...'
chmod +x extend_apache_web_server_with_security_module_template.sh 
./extend_apache_web_server_with_security_module_template.sh >> "${webphp_log_file}" 2>&1
echo 'Apache Web Server Security module installed'

## *** ##
## PHP ##
## *** ##

cd "${script_dir}" || exit

echo 'Installing PHP ...'
chmod +x install_php.sh 
./install_php.sh >> "${webphp_log_file}" 2>&1
echo 'PHP installed'

## ******* ##
## FastCGI ##
## ******* ##

cd "${script_dir}" || exit

echo 'Extending Apache Web Server with FastCGI ...'
chmod +x extend_apache_web_server_with_FCGI.sh 
./extend_apache_web_server_with_FCGI.sh >> "${webphp_log_file}" 2>&1
echo 'Apache Web Server extended with FastCGI'

## ***** ##
## Monit ##
## ***** ##

cd "${script_dir}" || exit

echo 'Installing Monit ...'
yum install -y monit >> "${webphp_log_file}" 2>&1 
cp -f monitrc /etc/monitrc

{
   systemctl disable chronyd.service 
   systemctl disable sshd.service 
   systemctl disable httpd.service
   systemctl disable php-fpm
   systemctl enable monit.service
   systemctl start monit.service
} >> "${webphp_log_file}" 2>&1

rm -f /etc/monit.d/logging

# Create an heartbeat endpoint targeted by Monit, see monitrc configuration file.
monit_docroot="${APACHE_DOCROOT_DIR}"/"${MONIT_DOCROOT_ID}"/public_html
mkdir --parents "${monit_docroot}"
touch "${monit_docroot}"/monit
echo ok > "${monit_docroot}"/monit

# Public pages permissions.
find "${monit_docroot}" -type d -exec chown root:root {} +
find "${monit_docroot}" -type d -exec chmod 755 {} +
find "${monit_docroot}" -type f -exec chown root:root {} +
find "${monit_docroot}" -type f -exec chmod 644 {} +

cd "${script_dir}" || exit

# Enable the Monit site (Apache Web Server hearttbeat).

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}" ]]
then
   cp "${MONIT_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}" 
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}" 
   echo 'Monit heartbeat endpoint enabled'
fi

echo 'Monit installed'

## ************* ##
## Load Balancer ##
## ************* ##

cd "${script_dir}" || exit

# Create an heart-beat endpoint targeted by the Load Balancer.
loadbalancer_docroot="${APACHE_DOCROOT_DIR}"/"${LOADBALANCER_DOCROOT_ID}"/public_html
mkdir --parents "${loadbalancer_docroot}"
touch "${loadbalancer_docroot}"/elb.htm
echo ok > "${loadbalancer_docroot}"/elb.htm

# Public pages permissions.
find "${loadbalancer_docroot}" -type d -exec chown root:root {} +
find "${loadbalancer_docroot}" -type d -exec chmod 755 {} +
find "${loadbalancer_docroot}" -type f -exec chown root:root {} +
find "${loadbalancer_docroot}" -type f -exec chmod 644 {} +

# Enable the Load Balancer endopoint.
if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" ]]
then
   cp "${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}" 
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" 
   echo 'Load Balancer healt-check endpoint enabled'
fi   

## ********
## ????????
## ********

## yum install -y mod_evasive
####   TODO cp -f mod_evasive.conf /etc/httpd/conf.d/mod_evasive.conf

# Remove expect
yum erase -y expect >> "${webphp_log_file}" 2>&1
amazon-linux-extras disable epel -y >> "${webphp_log_file}" 2>&1

echo 'Reboot the server'

exit 194


