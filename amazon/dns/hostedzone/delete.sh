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

get_loadbalancer_record_dns_name_value "${lbal_dns_nm}"
lbal_record_dns_nm="${__RESULT}"
       
if [[ -z "${lbal_record_dns_nm}" ]]
then
   echo '* WARN: load balancer record DNS name not found.'
else
   echo "* Load balancer DNS name: ${lbal_dns_nm}"
   echo "* Load balancer record DNS name: ${lbal_record_dns_nm}"
fi

get_loadbalancer_record_hosted_zone_value "${lbal_dns_nm}" 
lbal_record_hz_id="${__RESULT}"

if [[ -z "${lbal_record_hz_id}" ]]
then
   echo '* WARN: load balancer record hosted zone ID record not found.'
else
   echo "* Load balancer record hosted zone ID: ${lbal_record_hz_id}."
fi

admin_dns_nm="${ADMIN_INST_DNS_SUB_DOMAIN}.${MAXMIN_TLD}"
get_record_value 'A' "${admin_dns_nm}"
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
## load balancer www.admin.it record.
##

check_hosted_zone_has_loadbalancer_record "${lbal_dns_nm}"
has_lbal_record="${__RESULT}"

if [[ 'true' == "${has_lbal_record}" ]]
then
   echo 'Deleting load balance record ...'

   delete_loadbalancer_record \
       "${lbal_dns_nm}" "${lbal_record_dns_nm}" "${lbal_record_hz_id}"
   request_id="${__RESULT}"          
                                   
   get_record_request_status "${request_id}"
   status="${__RESULT}"

   echo "Load balance record, deleted (${status})"
fi

##
## Admin website admin.maxmin.it
##

check_hosted_zone_has_record 'A' "${admin_dns_nm}"
has_admin_record="${__RESULT}"

if [[ 'true' == "${has_admin_record}" ]]
then
   echo 'Deleting Admin web site record ...'

   delete_record 'A' "${admin_dns_nm}" "${admin_record_ip_addr}"
   request_id="${__RESULT}" 
                            
   get_record_request_status "${request_id}" 
   status="${__RESULT}"
   
   echo "Admin record, deleted (${status})"
fi

## 
## hosted zone maxmin.it
## 

check_hosted_zone_exists "${MAXMIN_TLD}"
exists="${__RESULT}"

if [[ -n "${exists}" ]]
then
   ## delete_hosted_zone "${MAXMIN_TLD}"

   ## echo "Hosted zone ${MAXMIN_TLD} deleted."
   echo "Hosted zone ${MAXMIN_TLD} not deleted."
else
   echo "Hosted zone ${MAXMIN_TLD} not deleted."
fi

echo

