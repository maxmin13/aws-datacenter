#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Creates the DNS record that points to the 
# Admin website and a DNS record alias that 
# points to the Load Balancer 
###############################################

echo '***************'
echo 'DNS hosted zone'
echo '***************'
echo

lbal_dns_nm="$(get_record_dns_name "${MAXMIN_TLD}" "${LBAL_DNS_SUB_DOMAIN}")"

if [[ -z "${lbal_dns_nm}" ]]
then
   echo '* WARN: Load Balancer DNS name not found.'
else
   echo "* Load Balancer DNS name: ${lbal_dns_nm}."
fi

lbal_dns_hosted_zone_id="$(get_record_hosted_zone_id "${MAXMIN_TLD}" "${LBAL_DNS_SUB_DOMAIN}")"

if [[ -z "${lbal_dns_hosted_zone_id}" ]]
then
   echo '* WARN: Load Balancer Hosted Zone ID not found.'
else
   echo "* Load Balancer Hosted Zone ID: ${lbal_dns_hosted_zone_id}."
fi

admin_eip="$(get_record_ip_address "${MAXMIN_TLD}" "${SRV_ADMIN_DNS_SUB_DOMAIN}")"

if [[ -z "${admin_eip}" ]]
then
   echo '* WARN: Admin IP address not found.'
else
   echo "* Admin IP address: ${admin_eip}."
fi

echo

##
## DNS records 
##

# Load Balancer: www.maxmin.it

if [[ -n "${lbal_dns_nm}" && -n "${lbal_dns_hosted_zone_id}" ]]
then
   ## Delete the Load Balancer alias 
   delete_alias_record "${lbal_dns_hosted_zone_id}" "${lbal_dns_nm}" "${MAXMIN_TLD}" "${LBAL_DNS_SUB_DOMAIN}" >> /dev/null
   
   echo "DNS record ${LBAL_DNS_SUB_DOMAIN}.${MAXMIN_TLD} deleted."
fi

# Admin website: admin.maxmin.it

if [[ -n "${admin_eip}" ]]
then
   ## Delete the Admin website DNS record.
   delete_record "${admin_eip}" "${MAXMIN_TLD}" "${SRV_ADMIN_DNS_SUB_DOMAIN}" >> /dev/null
   
   echo "DNS record ${SRV_ADMIN_DNS_SUB_DOMAIN}.${MAXMIN_TLD} deleted."
fi

## 
## hosted zone maxmin.it
## 

#exists="$(check_hosted_zone_exists "${MAXMIN_TLD}")"

## if [[ -n "${exists}" ]]
if false
then
   delete_hosted_zone "${MAXMIN_TLD}"
   
   echo
   echo "Hosted zone ${MAXMIN_TLD} deleted."
   echo
else
   echo
   echo "Hosted zone ${MAXMIN_TLD} not deleted."
   echo
fi

