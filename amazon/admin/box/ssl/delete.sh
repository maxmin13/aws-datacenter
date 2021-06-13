#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

APACHE_INSTALL_DIR='/etc/httpd'
APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
APACHE_USER='apache'
CERTBOT_VIRTUALHOST_CONFIG_FILE='certbot.virtualhost.maxmin.it.conf'
CERTBOT_DOCROOT_ID='admin.maxmin.it' 
CRT_PROVINCE_NM='Dublin'
CRT_CITY_NM='Dublin'
CRT_ORGANIZATION_NM='WWW'
CRT_UNIT_NM='UN'
ssl_certbot_dir='ssl/certbot'

echo '*********'
echo 'Admin SSL'
echo '*********'
echo



 
echo
