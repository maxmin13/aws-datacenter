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
## acme-dns server.
##

cd "${script_dir}" || exit 1

echo 'Installing acme-dns ...'

chmod +x install_acme_dns_server.sh 
./install_acme_dns_server.sh >> "${lbal_log_file}" 2>&1 

echo 'acme-dns installed.'

##
## acme.sh client
##

##
## SSL certifcates 
## 

echo 'Requesting SSL certificate ...'






exit 0
