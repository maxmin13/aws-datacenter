#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Remove BBL client client.
####################################################################

echo 'Removing Bosh bootloader client ...'

rm -f /usr/bin/bbl

echo 'Bosh bootloader client removed.'

exit 0

