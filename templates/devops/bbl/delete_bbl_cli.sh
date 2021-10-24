#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Remove BBL client and Terraform client.
####################################################################

echo 'Removing Terraform client ...'

rm -f /usr/bin/terraform

echo 'Terraform client removed.'

echo 'Removing Bosh bootloader client ...'

rm -f /usr/bin/bbl

echo 'Bosh bootloader client removed.'

exit 0

