#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################################
#
###################################################################################

lbal_log_file='/var/log/lbal_request_ssl_certificate.log'

############### TODO error retrieving current directory: getcwd: cannot access parent directories: No such file or directory
############### 
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
############### 
############### 

##
## aws client.
##

cd "${script_dir}" || exit 1

echo 'Installing aws client ...'

chmod +x install_aws_cli.sh
./install_aws_cli.sh >> "${lbal_log_file}" 2>&1 

echo 'aws client installed.'

##
## acme-dns server.
##

cd "${script_dir}" || exit 1

echo 'Installing acme-dns ...'

chmod +x install_acme_dns_server.sh 
./install_acme_dns_server.sh >> "${lbal_log_file}" 2>&1 

echo 'acme-dns installed.'

echo 'Registering www.maxmin.it domain with acme-dns server.'

registration_resp="$(curl -X POST https://www.maxmin.it/register)"

if ! jq -e . > /dev/null 2>&1 <<< "${registration_resp}"
then
   echo 'ERROR: registering www.maxmin.it domain with acme-dns server.'
   exit 1
fi

username="$(echo "${registration_resp}"   | jq -r '.username')"   
password="$(echo "${registration_resp}"   | jq -r '.password')"   
fulldomain="$(echo "${registration_resp}" | jq -r '.fulldomain')"
subdomain="$(echo "${registration_resp}"  | jq -r '.subdomain')"

echo 'Domain successfully registered with acme-dns server.'
echo "Username: ${username}"
echo "Password: ${password}"
echo "Fulldomain: ${fulldomain}"   
echo "Subdomain: ${subdomain}"
   


# We can now set up DNS accordingly.

##
## acme.sh client
##

# When the entries finished propagating we can install acme.sh and issue a certificate using the acme-dns method.
# All settings will be saved and the certificate will be renewed automatically.

curl https://get.acme.sh | sh

##
## SSL certifcates 
## 

echo 'Requesting SSL certificate ...'






exit 0
