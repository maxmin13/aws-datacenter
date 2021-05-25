#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Creates the DNS record that points to the 
# Admin website and a DNS record alis that 
# points to the load balancer 
###############################################

echo '***************'
echo 'DNS hosted zone'
echo '***************'
echo

lbal_dns_nm="$(get_loadbalancer_dns_name "${LBAL_NM}")"

if [[ -z "${lbal_dns_nm}" ]]
then
   echo '* WARN: load balancer not found'
else
   echo "* load balancer: '${lbal_dns_nm}'"
fi

lbal_dns_hosted_zone_id="$(get_loadbalancer_dns_hosted_zone_id "${LBAL_NM}")"

if [[ -z "${lbal_dns_hosted_zone_id}" ]]
then
   echo '* WARN: load balancer hosted zone not found'
else
   echo "* load balancer hosted zone: '${lbal_dns_hosted_zone_id}'"
fi

admin_eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_eip}" ]]
then
   echo '* WARN: admin public IP address not found'
else
   echo "* admin public IP address: '${admin_eip}'"
fi

echo

##
## DNS records 'admin.maxmin.it' and 'www.admin.it'
##

lbal_alias_record="$(check_hosted_zone_has_record "${LBAL_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"

if [[ -n "${lbal_alias_record}" ]]
then
   ## Delete the load balancer alias 
   delete_alias_record "${LBAL_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}" "${lbal_dns_nm}" "${lbal_dns_hosted_zone_id}" >> /dev/null
   echo "DNS record '${LBAL_DNS_SUB_DOMAIN}.${MAXMIN_TLD}' deleted"
fi

admin_record="$(check_hosted_zone_has_record "${SERVER_ADMIN_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"

if [[ -n "${admin_record}" ]]
then
   ## Delete the Admin website record.
   delete_record "${SERVER_ADMIN_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}" "${admin_eip}" >> /dev/null
   echo "DNS record '${SERVER_ADMIN_DNS_SUB_DOMAIN}.${MAXMIN_TLD}' deleted"
fi

## 
## hosted zone 'maxmin.it'
## 

#exists="$(check_hosted_zone_exists "${MAXMIN_TLD}")"

## if [[ -n "${exists}" ]]
if false
then
   delete_hosted_zone "${MAXMIN_TLD}"
   echo "Hosted zone '${MAXMIN_TLD}' deleted"
else
   echo "Hosted zone '${MAXMIN_TLD}' not deleted"
fi

echo
