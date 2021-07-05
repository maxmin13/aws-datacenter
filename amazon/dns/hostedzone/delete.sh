#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Creates the DNS record that points to the 
# Admin website and a DNS record alias that 
# points to the load balancer 
###############################################

echo '***************'
echo 'DNS hosted zone'
echo '***************'
echo

lbal_dns_nm="${LBAL_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}"
target_lbal_dns_nm="$(get_alias_record_dns_name_value \
   "${LBAL_INST_DNS_SUB_DOMAIN}" \
   "${MAXMIN_TLD}")" 
       
if [[ -z "${target_lbal_dns_nm}" ]]
then
   echo '* WARN: load balancer DNS record not found.'
else
   echo "* Load balancer DNS name: ${lbal_dns_nm}"
   echo "* Target load balancer name: ${target_lbal_dns_nm}"
fi

target_lbal_dns_hosted_zone_id="$(get_alias_record_hosted_zone_value \
   "${LBAL_INST_DNS_SUB_DOMAIN}" \
   "${MAXMIN_TLD}")" 

if [[ -z "${target_lbal_dns_hosted_zone_id}" ]]
then
   echo '* WARN: load balancer hosted zone DNS record not found.'
else
   echo "* Target load balancer hosted zone ID: ${target_lbal_dns_hosted_zone_id}."
fi

admin_dns_nm="${ADMIN_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}"
target_admin_eip="$(get_record_value "${ADMIN_INST_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"

if [[ -z "${target_admin_eip}" ]]
then
   echo '* WARN: Admin DNS record not found.'
else
   echo "* Admin DNS name: ${admin_dns_nm}."
   echo "* Target Admin IP address: ${target_admin_eip}."
fi

echo

##
## load balancer www.admin.it record.
##

has_lbal_record="$(check_hosted_zone_has_record "${LBAL_INST_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"

if [[ 'true' == "${has_lbal_record}" ]]
then
   echo 'Deleting load balance record ...'
   
   request_id="$(delete_alias_record \
       "${LBAL_INST_DNS_SUB_DOMAIN}" \
       "${MAXMIN_TLD}" \
       "${target_lbal_dns_nm}" \
       "${target_lbal_dns_hosted_zone_id}")"                                   
   status="$(get_record_request_status "${request_id}")"

   echo "Load balance record, deleted (${status})"
fi

##
## Admin website admin.maxmin.it
##

has_admin_record="$(check_hosted_zone_has_record "${ADMIN_INST_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"

if [[ 'true' == "${has_admin_record}" ]]
then
   echo 'Deleting Admin web site record ...'

   request_id="$(delete_record \
       "${ADMIN_INST_DNS_SUB_DOMAIN}" \
       "${MAXMIN_TLD}" \
       "${target_admin_eip}")"                            
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

echo

