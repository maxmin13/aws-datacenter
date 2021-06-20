#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
# Generates and installs a self-signed certificate in Apache web
# server.
#
# Dependencies:
# gen-rsa.sh 
# remove-passphase.sh 
# gen-selfsign-cert.sh
#
###################################################################

APACHE_INSTALL_DIR='SEDapache_install_dirSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Generating self-signed certificate ...'

amazon-linux-extras install epel -y 
yum install -y expect 

cd "${script_dir}" || exit 1

chmod +x gen-rsa.sh remove-passphase.sh gen-selfsign-cert.sh

key_file="$(./gen-rsa.sh)" 
new_key_file="$(./remove-passphase.sh)" 

rm "${key_file}"
mv "${new_key_file}" "${key_file}"

echo "No-password ${key_file} private-key generated."

cert_file="$(./gen-selfsign-cert.sh)"

echo "Self-signed ${cert_file} certificate created."
 
yum remove -y expect 
amazon-linux-extras disable epel -y 

cp "${cert_file}" "${APACHE_INSTALL_DIR}"/ssl
cp "${key_file}" "${APACHE_INSTALL_DIR}"/ssl

find "${APACHE_INSTALL_DIR}"/ssl -type d -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/ssl -type d -exec chmod 500 {} +
find "${APACHE_INSTALL_DIR}"/ssl -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/ssl -type f -exec chmod 400 {} +

# Enable the certificate paths.
sed -i "s/^#SSLCertificateKeyFile/SSLCertificateKeyFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf
sed -i "s/^#SSLCertificateFile/SSLCertificateFile/g" "${APACHE_INSTALL_DIR}"/conf.d/ssl.conf 

echo 'Self-signed Certificate successfully installed in Apache web server.'

exit 0
