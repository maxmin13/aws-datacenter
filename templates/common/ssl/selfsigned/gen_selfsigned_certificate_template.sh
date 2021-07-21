#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
# Generates a private-key with no password and a self-signed 
# certificate in following directory:
#
# /etc/self-signed/live/admin.maxmin.it/
#
# cert.pem
# key.pem
#
###################################################################

ADMIN_DOCROOT_ID='SEDadmin_docroot_idSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Generating self-signed certificate ...'

set +e
amazon-linux-extras install epel -y > /dev/null 2>&1
set -e 
set +e
yum install -y expect > /dev/null 2>&1
set -e

cd "${script_dir}" || exit 1

chmod +x gen_rsa.sh remove_passphase.sh gen_certificate.sh

key_file="$(./gen_rsa.sh)" 
new_key_file="$(./remove_passphase.sh)" 

rm "${key_file}"
mv "${new_key_file}" "${key_file}"

echo "No-password ${key_file} private-key generated."

cert_file="$(./gen_certificate.sh)"

echo "Self-signed ${cert_file} certificate created."

certificate_dir=/etc/self-signed/live/"${ADMIN_DOCROOT_ID}"
mkdir -p "${certificate_dir}"
cp "${key_file}" "${cert_file}" "${certificate_dir}"

find "${certificate_dir}" -type d -exec chown root:root {} +
find "${certificate_dir}" -type d -exec chmod 500 {} +
find "${certificate_dir}" -type f -exec chown root:root {} +
find "${certificate_dir}" -type f -exec chmod 400 {} +

echo "Certificates copied in the "${certificate_dir}" directory."

set +e 
yum remove -y expect > /dev/null 2>&1
set -e 
set +e
amazon-linux-extras disable epel -y > /dev/null 2>&1
set -e 

exit 0
