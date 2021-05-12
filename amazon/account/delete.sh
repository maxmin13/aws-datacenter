#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## *************************
## Delete Account components
## *************************

echo 'Deleting Account components ...'
echo 

echo 'Releasing public IP addresses allocated to the account ...'

allocation_ids="$(get_all_allocation_ids)"

if [[ -n "${allocation_ids}" ]]; then
   echo "Found '${allocation_ids}' allocation identifiers of public IP addresses" 
   release_all_public_ip_addresses "${allocation_ids}"
   echo 'Deleted all allocated public IP address'
else
   echo 'No allocated public IP addresses found'
fi

echo 'Accounts components deleted'
echo 
