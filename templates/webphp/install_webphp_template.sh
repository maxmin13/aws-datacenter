#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Install a Linux Apache PHP server (LAP).

ENV='SEDenvironmentSED'
SERVER_WEBPHP_HOSTNAME='SEDserver_webphp_hostnameSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
LOADBALANCER_VIRTUALHOST_CONFIG_FILE='SEDloadbalancer_virtualhost_configSED'
LOADBALANCER_DOCROOT_ID='SEDloadbalancer_docroot_idSED'
MONIT_VIRTUALHOST_CONFIG_FILE='SEDmonit_virtualhost_configSED'
MONIT_DOCROOT_ID='SEDmonit_docroot_idSED'
webphp_log_file=/var/log/webphp_install.log

amazon-linux-extras install epel -y >> "${webphp_log_file}" 2>&1

## *************** ##
## System hostname ##
## *************** ##

if [[ 'development' == "${ENV}" ]]
then
   hostnamectl set-hostname "${SERVER_WEBPHP_HOSTNAME}"
   awk -v domain="${SERVER_WEBPHP_HOSTNAME}" '{if($1 == "127.0.0.1"){$2=domain;$3=domain".localdomain"; print $0} else {print $0}}' /etc/hosts > tmp
   mv tmp /etc/hosts
   echo 'System hostname modified'
elif [[ 'production' == "${ENV}" ]]
then
   hostnamectl set-hostname "${SERVER_WEBPHP_HOSTNAME}"
   hostname
   echo 'System hostname modified'
fi

## ********************* ##
## 'root' and 'ec2-user' ##
## ********************* ##

cd /home/ec2-user || exit

yum install -y expect >> "${webphp_log_file}" 2>&1

{
   chmod +x chp_ec2-user.sh
   ./chp_ec2-user.sh 
   echo "'ec2-user' user password set"
   
   # Set ec2-user's sudo with password'
   echo 'ec2-user ALL = ALL' > /etc/sudoers.d/cloud-init
   echo 'ec2-user no password set' 
   
   chmod +x chp_root.sh
   ./chp_root.sh
   echo "'root' user password set"
} >> "${webphp_log_file}" 2>&1

echo 'Users root and ec2-user configured'

## ******* ##
## Rsyslog ##
## ******* ##

cd /home/ec2-user || exit
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

echo 'Installing Apache Web Server ...'
cd /home/ec2-user || exit
chmod +x install_apache_web_server.sh 
./install_apache_web_server.sh >> "${webphp_log_file}" 2>&1
echo 'Apache Web Server installed'

## *************** ##
## Security Module ##
## *************** ##

echo 'Installing Apache Web Server Security module ...'
cd /home/ec2-user || exit
chmod +x extend_apache_web_server_with_security_module_template.sh 
./extend_apache_web_server_with_security_module_template.sh >> "${webphp_log_file}" 2>&1
echo 'Apache Web Server Security module installed'

## *** ##
## PHP ##
## *** ##

echo 'Installing PHP ...'
cd /home/ec2-user || exit
chmod +x install_php.sh 
./install_php.sh >> "${webphp_log_file}" 2>&1
echo 'PHP installed'

## ******* ##
## FastCGI ##
## ******* ##

echo 'Extending Apache Web Server with FastCGI ...'
cd /home/ec2-user || exit
chmod +x extend_apache_web_server_with_FCGI.sh 
./extend_apache_web_server_with_FCGI.sh >> "${webphp_log_file}" 2>&1
echo 'Apache Web Server extended with FastCGI'

## ***** ##
## Monit ##
## ***** ##

echo 'Installing Monit ...'
yum install -y monit >> "${webphp_log_file}" 2>&1 

cd /home/ec2-user || exit
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
monit_doc_root="${APACHE_DOCROOT_DIR}"/"${MONIT_DOCROOT_ID}"/public_html
mkdir --parents "${monit_doc_root}"
touch "${monit_doc_root}"/monit
echo ok > "${monit_doc_root}"/monit

cd /home/ec2-user || exit

# Enable the Monit site (Apache Web Server hearttbeat).
cp "${MONIT_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}" 
ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${MONIT_VIRTUALHOST_CONFIG_FILE}" 
echo 'Monit heartbeat endpoint enabled'
echo 'Monit installed'

## ************* ##
## Load Balancer ##
## ************* ##

cd /home/ec2-user || exit

# Create an heart-beat endpoint targeted by the Load Balancer.
loadbalancer_doc_root="${APACHE_DOCROOT_DIR}"/"${LOADBALANCER_DOCROOT_ID}"/public_html
mkdir --parents "${loadbalancer_doc_root}"
touch "${loadbalancer_doc_root}"/elb.htm
echo ok > "${loadbalancer_doc_root}"/elb.htm

# Enable the Load Balancer endopoint.
cp "${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}" 
ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${LOADBALANCER_VIRTUALHOST_CONFIG_FILE}" 
echo 'Load Balancer healt-check endpoint enabled'

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

