#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
# The script installs Certbot ACME client and runs the 'certbot' 
# command to request a certificate for the 'maxmin.it' domain to
# Let’s Encrypt CA.
#
# In this script Let’s Encrypt CA uses the HTTP-01 challege to 
# verify your control over the maxmin.it domain. In this challenge 
# the certificate authority will expect a specified file  to be 
# posted in a specified location on a web site. The file will 
# be downloaded using an HTTP request on TCP port 80. Since part  
# of what this challenge shows is the ability to create a file at  
# an arbitrary location, you cannot choose a different location or 
# port number.
#
# Let’s Encrypt CA issues short-lived certificates (90 days). 
# Most Certbot installations come with automatic renewals 
# preconfigured. This is done by means of a scheduled task which 
# runs 'certbot renew' periodically.

#
# /etc/letsencrypt/live/admin.maxmin.it/
#
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
APACHE_CERTBOT_HTTP_PORT='SEDapache_certbot_portSED'
CERTBOT_VIRTUALHOST_CONFIG_FILE='SEDcertbot_virtualhost_config_fileSED'
ADMIN_DOCROOT_ID='SEDadmin_docroot_idSED'
CRT_EMAIL_ADDRESS='SEDcrt_email_addressSED'
CRT_DOMAIN='SEDcrt_domainSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


echo 'Requesting SSL certificates to Let''Encrypt.'

# Make Apache listen on Certbot port.
sed -i "s/^##certboot_anchor##/Listen ${APACHE_CERTBOT_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo "Enabled Apache Listen on Certbot port ${APACHE_CERTBOT_HTTP_PORT}."

cd "${script_dir}" || exit

# Create the directory of the http-01 challege.
certbot_docroot="${APACHE_DOCROOT_DIR}"/"${ADMIN_DOCROOT_ID}"/public_html
mkdir --parents "${certbot_docroot}"
find "${certbot_docroot}" -type d -exec chown root:root {} +
find "${certbot_docroot}" -type d -exec chmod 755 {} +

# Enable Certbot HTTP virtualhost.
cp "${CERTBOT_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_AVAILABLE_DIR}"

if [[ ! -f "${APACHE_SITES_ENABLED_DIR}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" ]]
then   
   ln -s "${APACHE_SITES_AVAILABLE_DIR}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}" "${APACHE_SITES_ENABLED_DIR}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}"

   echo 'Certbot HTTP virtual host enabled.'
fi

httpd -t 
systemctl restart httpd 

echo 'Apache web server restarted and ready for Certbot.'

# Install and run Certbot

echo 'Installing Certbot SSL agent ...'

yum remove -y certbot  
yum install -y certbot python2-certbot-apache 

echo 'Certbot SSL agent installed.'
echo "Requesting a certificate to Let's Encrypt Certification Autority ..."

## If you’re running a local webserver for which you have the ability to modify the content being 
## served, and you’d prefer not to stop the webserver during the certificate issuance process, 
## you can use the webroot plugin to obtain a certificate by including 'certonly' and '--webroot' on  
## the command line. 
## In addition, you’ll need to specify '--webroot-path' or '-w' with the top-level directory 
## (“web root”) containing the files served by your webserver.

set +e 
    
## TODO remove Certbot test mode    
certbot certonly \
    --webroot \
    -w "${certbot_docroot}" \
    -d "${CRT_DOMAIN}" \
    -m "${CRT_EMAIL_ADDRESS}" \
    --non-interactive \
    --agree-tos \
    --test-cert    

exit_code=$?
set -e 

find /etc/letsencrypt/live/"${ADMIN_DOCROOT_ID}" -type d -exec chown root:root {} +
find /etc/letsencrypt/live/"${ADMIN_DOCROOT_ID}" -type d -exec chmod 500 {} +
find /etc/letsencrypt/live/"${ADMIN_DOCROOT_ID}" -type f -exec chown root:root {} +
find /etc/letsencrypt/live/"${ADMIN_DOCROOT_ID}" -type f -exec chmod 400 {} +

# Disable Certbot HTTP virtual host.
rm "${APACHE_SITES_ENABLED_DIR}"/"${CERTBOT_VIRTUALHOST_CONFIG_FILE}"

echo 'Certbot virtual hosts disabled.'

# Disable Apache listen on Certbot port.
sed -i "s/^#Listen \+${APACHE_CERTBOT_HTTP_PORT}$/Listen ${APACHE_CERTBOT_HTTP_PORT}/g" "${APACHE_INSTALL_DIR}"/conf/httpd.conf

echo "Disabled Apache Listen on Certbot port ${APACHE_CERTBOT_HTTP_PORT}."

httpd -t 
systemctl restart httpd 

echo 'Apache web server restarted' 

if [[ ! 0 -eq "${exit_code}" ]]
then
   echo "ERROR: requesting a certificate to Let's Encrypted certification authority."
   
   exit "${exit_code}"
else
   echo "Certificate successfully obtained from Let's Encrypted certification authority."
fi

echo 'Let''s Encrypt certificates successfully requested.'

exit 0
