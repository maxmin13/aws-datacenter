#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
# The script installs Certbot ACME client and runs the 'certbot' 
# command to request a certificate for the 'maxmin.it' domain.
# The certificate is stored in /etc/letsencrypt/live directory.
# It is not not installed in Apache web server.
# The script configures also the automatc certificate renewal as a 
# Cron job. 
#
# /etc/letsencrypt/live/admin.maxmin.it
# cert.pem
# chain.pem
# fullchain.pem
# privkey.pem
#
###################################################################

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_DOCROOT_DIR='SEDapache_docroot_dirSED'
APACHE_SITES_AVAILABLE_DIR='SEDapache_sites_available_dirSED'
APACHE_SITES_ENABLED_DIR='SEDapache_sites_enabled_dirSED'
CERTBOT_VIRTUALHOST_CONFIG_FILE='SEDcertbot_virtualhost_fileSED'
CERTBOT_DOCROOT_ID='SEDcertbot_docroot_idSED'
EMAIL_ADDRESS='SEDemail_addressSED'
DNS_DOMAIN='SEDdns_domainSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make Apache listen on port 80
sed -i "s/^#SEDlisten_port_80SED/Listen 80/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo 'Enabled Apache Listen on port 80.'

cd "${script_dir}" || exit

certbot_docroot="${APACHE_DOCROOT_DIR}"/"${CERTBOT_DOCROOT_ID}"/public_html
mkdir --parents "${certbot_docroot}"
find "${certbot_docroot}" -type d -exec chown root:root {} +
find "${certbot_docroot}" -type d -exec chmod 755 {} +

# Enable Certbot HTTP virtual host.

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" ]]
then
   cp "${CERTBOT_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}"

   echo 'Certbot HTTP virtual host enabled.'
fi

systemctl restart httpd 

echo 'Apache web server restarted.'

# Install and run Certbot
yum remove -y certbot 
yum install -y certbot python2-certbot-apache

echo 'Certbot SSL agent installed.'
echo "Requesting a certificate to Let's Encrypt Certification Autority ..."

set +e 

## TODO remove test mode
certbot certonly \
    --webroot \
    -w "${certbot_docroot}" \
    -d "${DNS_DOMAIN}" \
    -m "${EMAIL_ADDRESS}" \
    --agree-tos \
    --test-cert

exit_code=$?
set -e 

# Disable Certbot HTTP virtual host.
rm "${APACHE_SITES_ENABLED_DIR}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}"

echo 'Certbot virtual hosts disabled.'

# Disable Apache listen on port 80
sed -i "s/Listen 80/#SEDlisten_port_80SED/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo 'Disabled Apache Listen on port 80.'

systemctl restart httpd 

if [[ ! 0 -eq "${exit_code}" ]]
then
   echo "ERROR: requesting a certificate to Let's Encrypted certification authority."
   
   exit "${exit_code}"
else
   echo "Certificate successfully obtained from Let's Encrypted certification authority."
fi

#####
##### TODO
##### AUTOMATIC RENEWAL
#####
##### echo 'Certificate authomatic renewal tested.'
#####

exit 0
