#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
#
# The script generates an RSA key without password and a 
# self-signed certificate in the 
# /etc/self-signed/live/admin.maxmin.it/ directory.
#
# key.pem
# cert.pem
#
###################################################################

ADMIN_DOCROOT_ID='SEDadmin_docroot_dirSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Generating self-signed SSL certificate ...'

chmod +x gen_selfsigned_certificate.sh     
./gen_selfsigned_certificate.sh
   
mkdir -p /etc/self-signed/live/"${ADMIN_DOCROOT_ID}"
mv cert.pem key.pem /etc/self-signed/live/"${ADMIN_DOCROOT_ID}"
   
find /etc/self-signed/live/"${ADMIN_DOCROOT_ID}" -type d -exec chown root:root {} +
find /etc/self-signed/live/"${ADMIN_DOCROOT_ID}" -type d -exec chmod 500 {} +
find /etc/self-signed/live/"${ADMIN_DOCROOT_ID}" -type f -exec chown root:root {} +
find /etc/self-signed/live/"${ADMIN_DOCROOT_ID}" -type f -exec chmod 400 {} +

echo 'Self-signed SSL certificate successfully generated.'

exit 0
