#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${script_dir}" || exit

echo 'Installing Certbot SSL agent ...'

# Make Apache listen on port 80

sed -i "s/^#SEDlisten_port_80SED/Listen 80/g" ${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo 'Enabled Apache Listen on port 80'

amazon-linux-extras install epel -y 

echo "Installing Certbot ..."

# Remove certbot-auto and any Certbot OS packages.
yum remove certbot

# Install certbot.
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

echo 'Certbot installed'

# Have Certbot edit your Apache configuration automatically to serve it, turning on HTTPS access in a single step.
# certbot certonly --apache

##### echo 'Getting a certificate for Apache web server ...'

# If you're feeling more conservative and would like to make the changes to your Apache configuration by hand, run this command.
##### sudo certbot certonly --apache


##### echo 'Certificate requested'

# The Certbot packages on your system come with a cron job or systemd timer that will renew 
# your certificates automatically before they expire. You will not need to run Certbot again, 
# unless you change your configuration. 
# The command to renew certbot is installed in one of the following locations:
# /etc/crontab/
# /etc/cron.*/*
# systemctl list-timers
# You can test automatic renewal for your certificates:

##### certbot renew --dry-run
##### amazon-linux-extras disable epel -y 

##### echo 'Certificate authomatic renewal tested'


