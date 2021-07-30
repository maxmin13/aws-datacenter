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

lbal_dns_nm="${LBAL_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}"

get_loadbalancer_record_dns_name_value "${LBAL_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}"
lbal_record_dns_nm="${__RESULT}"
       
if [[ -z "${lbal_record_dns_nm}" ]]
then
   echo '* WARN: load balancer record DNS name not found.'
else
   echo "* Load balancer DNS name: ${lbal_dns_nm}"
   echo "* Load balancer record DNS name: ${lbal_record_dns_nm}"
fi

lbal_record_hz_id="$(get_loadbalancer_record_hosted_zone_value \
   "${LBAL_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}")" 

if [[ -z "${lbal_record_hz_id}" ]]
then
   echo '* WARN: load balancer record hosted zone ID record not found.'
else
   echo "* Load balancer record hosted zone ID: ${lbal_record_hz_id}."
fi

admin_dns_nm="${ADMIN_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}"

get_record_value 'A' "${ADMIN_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}"
admin_record_ip_addr="${__RESULT}"

if [[ -z "${admin_record_ip_addr}" ]]
then
   echo '* WARN: Admin record IP address not found.'
else
   echo "* Admin DNS name: ${admin_dns_nm}."
   echo "* Admin record IP address: ${admin_record_ip_addr}."
fi

echo

## 
## Hosted Zone maxmin.it
## 

check_hosted_zone_exists "${MAXMIN_TLD}"
exists="${__RESULT}"

if [[ -n "${exists}" ]]
then
   echo "WARN: Hosted zone ${MAXMIN_TLD} already created."
else
   echo "Creating ${MAXMIN_TLD} hosted zone ..."

   create_hosted_zone "${MAXMIN_TLD}" 'ref_hz_maxmin_it' 'maxmin.it public hosted zone'
  
   echo "Hosted zone ${MAXMIN_TLD} creation in progress, it may take up to 48 hours to complete."
   
   ## Update the domain registration to use the hosted zone name servers

   echo 'Updating the list of name servers in the domain registration ...'

   hosted_zone_name_servers="$(get_hosted_zone_name_servers "${MAXMIN_TLD}")"
   update_domain_registration_name_servers "${MAXMIN_TLD}" "${hosted_zone_name_servers}"
   
   echo 'Domain registration name servers update in progress.'
fi

##
## load balancer www.admin.it record.
##

check_hosted_zone_has_loadbalancer_record "${LBAL_INST_DNS_SUB_DOMAIN}" "${MAXMIN_TLD}"
has_lbal_record="${__RESULT}"

if [[ 'true' == "${has_lbal_record}" ]]
then
   echo 'WARN: found load balance record, deleting ...'
   
   delete_loadbalancer_record \
       "${LBAL_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}" "${lbal_record_dns_nm}" "${lbal_record_hz_id}"
   request_id="${__RESULT}"
                                   
   get_record_request_status "${request_id}"
   status="${__RESULT}"

   echo "Load balancer record deleted (${status})"
fi

## Create an alias that points to the load balancer 

target_lbal_dns_nm="$(get_loadbalancer_dns_name "${LBAL_INST_NM}")"
target_lbal_dns_hosted_zone_id="$(get_loadbalancer_hosted_zone_id "${LBAL_INST_NM}")"

create_loadbalancer_record \
    "${LBAL_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}" "${target_lbal_dns_nm}" "${target_lbal_dns_hosted_zone_id}"
request_id="${__RESULT}"     
                                       
get_record_request_status "${request_id}"
status="${__RESULT}"
   
echo "Load balancer record ${lbal_dns_nm} created (${status})."

##
## Admin website admin.maxmin.it record.
##

check_hosted_zone_has_record 'A' "${ADMIN_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}"
has_admin_record="${__RESULT}"

if [[ 'true' == "${has_admin_record}" ]]
then
   echo 'WARN: found Admin web site record, deleting ...'

   delete_record 'A' "${ADMIN_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}" "${admin_record_ip_addr}" 
   request_id="${__RESULT}"
                                 
   get_record_request_status "${request_id}"
   status="${__RESULT}"
   
   echo "Admin record deleted (${status})"
fi

# Create a record that points to the Admin website

target_admin_eip="$(get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}")"

create_record 'A' "${ADMIN_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}" "${target_admin_eip}"       
request_id="${__RESULT}"
                          
get_record_request_status "${request_id}"
status="${__RESULT}"
   
echo "Admin record ${admin_dns_nm} created (${status})."

echo
echo 'Hosted Zone created.'
echo
