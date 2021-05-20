#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*******'
echo 'Account'
echo '*******'
echo

allocation_ids="$(get_all_allocation_ids)"

if [[ -z "${allocation_ids}" ]]
then
   echo 'WARN: not found any public IP address allocated with the account'
else
   echo "* public IP address allocation IDs: '${allocation_ids}'"
fi

echo

if [[ -n "${allocation_ids}" ]]; then
   release_all_public_ip_addresses "${allocation_ids}"
   echo 'Released all allocated public IP addresses'
fi

echo 
