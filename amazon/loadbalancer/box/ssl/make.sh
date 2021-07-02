#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

CRT_NM='maxmin-dev-elb-cert'
CRT_FILE='maxmin-dev-elb-cert.pem'
KEY_FILE='maxmin-dev-elb-key.pem'
CHAIN_FILE='maxmin-dev-elb-chain.pem'
CRT_COUNTRY_NM='IE'
CRT_PROVINCE_NM='Dublin'
CRT_CITY_NM='Dublin'
CRT_COMPANY_NM='maxmin13'
CRT_ORGANIZATION_NM='WWW'
CRT_UNIT_NM='UN'
CRT_COMMON_NM='www.maxmin.it'

function __wait()
{
   count=0
   while [[ ${count} -lt 15 ]]; do
      count=$((count+3))
      printf '.'
      sleep 3
   done
   printf '\n'
}

loadbalancer_dir='loadbalancer'

echo '*****************'
echo 'SSL load balancer'
echo '*****************'
echo

echo

elb_dns="$(get_loadbalancer_dns_name "${LBAL_NM}")"

if [[ -z "${elb_dns}" ]]
then
   echo '* ERROR: Load balancer box not found.'
   exit 1
else
   echo "* Load balancer DNS name: ${elb_dns}."
fi

sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: security group not found.'
   exit 1
else
   echo "* security group ID: ${sgp_id}."
fi

echo 

# Removing old files
rm -rf "${TMP_DIR:?}"/"${loadbalancer_dir}"
mkdir "${TMP_DIR}"/"${loadbalancer_dir}"

granted_https="$(check_access_from_cidr_is_granted  "${sgp_id}" "${LBAL_HTTPS_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_https}" ]]
then
   echo 'WARN: Internet access to the load balancer already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${LBAL_HTTPS_PORT}" '0.0.0.0/0'
   
   echo 'Granted HTTPS access to the load balancer from anywhere in the Internet.'
fi
