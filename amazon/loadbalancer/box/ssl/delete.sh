#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

CRT_NM='maxmin-dev-elb-cert'

echo '*****************'
echo 'SSL load balancer'
echo '*****************'
echo

cert_arn="$(get_server_certificate_arn "${CRT_NM}")"

if [[ -z "${cert_arn}" ]]
then
   echo '* WARN: SSL certificate not found.'
else
   echo "* SSL certificate: ${cert_arn}."
fi

echo

## 
## Delete the server certificate in IAM.
## 
  
if [[ -n "${cert_arn}" ]]
then
   delete_server_certificate "${CRT_NM}"
   
   echo 'Load balancer certificate deleted.'
   echo
fi