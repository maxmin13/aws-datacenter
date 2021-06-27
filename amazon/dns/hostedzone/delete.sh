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

lbal_dns_nm="$(get_loadbalancer_dns_name "${LBAL_NM}")"

if [[ -z "${lbal_dns_nm}" ]]
then
   echo '* ERROR: Load Balancer not found.'
   
   exit 1
else
   echo "* Load Balancer: ${lbal_dns_nm}."
fi

lbal_dns_hosted_zone_id="$(get_loadbalancer_dns_hosted_zone_id "${LBAL_NM}")"

if [[ -z "${lbal_dns_hosted_zone_id}" ]]
then
   echo '* ERROR: Load Balancer hosted zone not found.'
   
   exit 1
else
   echo "* Load Balancer hosted zone: ${lbal_dns_hosted_zone_id}."
fi

admin_eip="$(get_public_ip_address_associated_with_instance "${SRV_ADMIN_NM}")"

if [[ -z "${admin_eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   
   exit 1
else
   echo "* Admin public IP address: ${admin_eip}."
fi

echo

##
## DNS records 
##

#
# Load Balancer www.admin.it
#

has_lbal_record="$(check_hosted_zone_has_record "${LBAL_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"

if [[ 'true' == "${has_lbal_record}" ]]
then
   echo 'Deleting load balance record ...'
   
   request_id="$(delete_alias_record "${LBAL_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}" \
       "${lbal_dns_nm}" "${lbal_dns_hosted_zone_id}")"                                   
   status="$(get_record_request_status "${request_id}")"

   echo "Load balance record, deleted (${status})"
fi

##
## Admin website admin.maxmin.it
##

has_admin_record="$(check_hosted_zone_has_record "${SRV_ADMIN_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"

if [[ 'true' == "${has_admin_record}" ]]
then

   echo 'Deleting Admin web site record ...'

   request_id="$(delete_record "${SRV_ADMIN_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}" "${admin_eip}")"                            
   status="$(get_record_request_status "${request_id}")"  
   
   echo "Admin record, deleted (${status})"
fi

## 
## hosted zone maxmin.it
## 

#exists="$(check_hosted_zone_exists "${MAXMIN_TLD}")"

## if [[ -n "${exists}" ]]
if false
then
   delete_hosted_zone "${MAXMIN_TLD}"

   echo "Hosted zone ${MAXMIN_TLD} deleted."
else
   echo "Hosted zone ${MAXMIN_TLD} not deleted."
fi

