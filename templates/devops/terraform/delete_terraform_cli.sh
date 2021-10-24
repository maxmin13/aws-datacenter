#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Remove Terraform client.
####################################################################

echo 'Removing Terraform client ...'

rm -f /usr/bin/terraform

echo 'Terraform client removed.'

exit 0

