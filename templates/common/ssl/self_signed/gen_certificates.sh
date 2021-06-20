#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
# Generates a private-key with no password and self-signed 
# certificate in the current directory.
#
# Dependencies:
# gen-rsa.sh 
# remove-passphase.sh 
# gen-selfsign-cert.sh
#
###################################################################

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

exit 0
