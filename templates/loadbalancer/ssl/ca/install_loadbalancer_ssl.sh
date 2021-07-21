#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

############################################################
#
# Dependencies:
#
#
############################################################

acme_dns_install_log_file='/var/log/acme_dns_install_log_file.log'

############### TODO error retrieving current directory: getcwd: cannot access parent directories: No such file or directory
############### 
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
############### 
############### 
 
##
## Acme-dns server.
##

echo 'Installing acme-dns server ...'

cd "${script_dir}" || exit 1

chmod +x install_acme_dns_server.sh 
./install_acme_dns_server.sh >> "${acme_dns_install_log_file}" 2>&1 

echo 'acme-dns server installed.'

### TODO make script to install and submit certificate request to acme.sh script.

exit 0

