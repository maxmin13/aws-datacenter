#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

################################################
# Checks if the 'maxmin.it' hosted zone exists,
# if not creates it and update the domain
# registration with the list of the hosted zone
# name servers.
# Creates a DNS record 'admin.maxmin.it' that 
# points to the Admin website IP address and a 
# DNS record (alias) 'www.maxmin.it' that points 
# to the load balancer DNS name.
################################################

echo '***************'
echo 'DNS hosted zone'
echo '***************'
echo

lbal_dns_nm="$(get_loadbalancer_dns_name "${LBAL_NM}")"
if [[ -z "${lbal_dns_nm}" ]]
then
   echo '* ERROR: load balancer not found'
   exit 1
else
   echo "* load balancer: '${lbal_dns_nm}'"
fi

lbal_dns_hosted_zone_id="$(get_loadbalancer_dns_hosted_zone_id "${LBAL_NM}")"
if [[ -z "${lbal_dns_hosted_zone_id}" ]]
then
   echo '* ERROR: load balancer hosted zone not found'
   exit 1
else
   echo "* load balancer hosted zone: '${lbal_dns_hosted_zone_id}'"
fi

admin_eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_eip}" ]]
then
   echo '* ERROR: admin public IP address not found'
   exit 1
else
   echo "* admin public IP address: '${admin_eip}'"
fi

echo

## 
## hosted zone 'maxmin.it'
## 

exists="$(check_hosted_zone_exists "${MAXMIN_TLD}")"

if [[ -n "${exists}" ]]
then
   echo "Hosted zone '${MAXMIN_TLD}' already created"
else
   echo "Creating '${MAXMIN_TLD}' hosted zone ..."

   create_hosted_zone "${MAXMIN_TLD}" 'ref_hz_maxmin_it' 'maxmin.it public hosted zone'
  
   echo "Hosted zone '${MAXMIN_TLD}' creation in progress, it may take up to 48 hours to complete"
   
   ## Update the domain registration to use the hosted zone name servers

   echo 'Updating the list of name servers in the domain registration ...'

   hosted_zone_name_servers="$(get_hosted_zone_name_servers "${MAXMIN_TLD}")"
   update_domain_registration_name_servers "${MAXMIN_TLD}" "${hosted_zone_name_servers}"
   
   echo 'Domain registration name servers update in progress'
fi

##
## DNS records 'admin.maxmin.it' and 'www.admin.it'
##

lbal_alias_record="$(check_hosted_zone_has_record "${LBAL_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"
                             
if [[ -z "${lbal_alias_record}" ]]
then
   ## Create an alias that points to the load balancer 
   request_id="$(create_alias_record "${LBAL_DNS_SUB_DOMAIN}" \
                                     "${MAXMIN_TLD}" \
                                     "${lbal_dns_nm}" \
                                     "${lbal_dns_hosted_zone_id}")"
                                     
   status="$(get_record_request_status "${request_id}")"
   
   echo "Created a DNS record '${LBAL_DNS_SUB_DOMAIN}.${MAXMIN_TLD}' that points to the load balancer IP address, ${status}"
else
   echo "DNS record '${LBAL_DNS_SUB_DOMAIN}.${MAXMIN_TLD}' already created"
fi

admin_record="$(check_hosted_zone_has_record "${SERVER_ADMIN_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}")"

if [[ -z "${admin_record}" ]]
then
   ## Create a record that points to the Admin website
   request_id="$(create_record "${SERVER_ADMIN_DNS_SUB_DOMAIN}" \
                               "${MAXMIN_TLD}" \
                               "${admin_eip}")"
                               
   status="$(get_record_request_status "${request_id}")"  
   
   echo "Created a DNS record '${SERVER_ADMIN_DNS_SUB_DOMAIN}.${MAXMIN_TLD}' that points to the Admin web site IP address, ${status}"
else
   echo "DNS record '${SERVER_ADMIN_DNS_SUB_DOMAIN}.${MAXMIN_TLD}' already created"
fi

echo
