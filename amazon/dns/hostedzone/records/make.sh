#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#############################################################################
# Checks if the 'maxmin.it' hosted zone exists, if not found, the script 
# exits with error. 
# The script creates a DNS record 'admin.maxmin.it' that points to the Admin
# website IP address and a DNS record (alias) 'www.maxmin.it' that points 
# to the load balancer DNS name. The records are cleared when the delete.sh
# is run.
###########################################################################

echo
echo '***********'
echo 'DNS records'
echo '***********'
echo

check_hosted_zone_exists "${MAXMIN_TLD}"
exists="${__RESULT}"

if [[ 'false' == "${exists}" ]]
then
   echo "ERROR: hosted zone ${MAXMIN_TLD} not found."
   exit 1
fi

lbal_dns_nm="${LBAL_INST_DNS_DOMAIN_NM}"

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

admin_dns_nm="${ADMIN_INST_DNS_DOMAIN_NM}"

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
   echo 'WARN: found load balance record, deleting ...'
   
   delete_loadbalancer_record \
       "${lbal_dns_nm}" "${lbal_record_dns_nm}" "${lbal_record_hz_id}"
   request_id="${__RESULT}"
                                   
   get_record_request_status "${request_id}"
   status="${__RESULT}"

   echo "Load balancer record deleted (${status})"
fi

## Create an alias that points to the load balancer 

get_loadbalancer_dns_name "${LBAL_INST_NM}"
target_lbal_dns_nm="${__RESULT}" 

get_loadbalancer_hosted_zone_id "${LBAL_INST_NM}"
target_lbal_dns_hosted_zone_id="${__RESULT}" 

create_loadbalancer_record "${lbal_dns_nm}" "${target_lbal_dns_nm}" "${target_lbal_dns_hosted_zone_id}"
request_id="${__RESULT}"     
                                       
get_record_request_status "${request_id}"
status="${__RESULT}"
   
echo "Load balancer record ${lbal_dns_nm} created (${status})."

##
## Admin website admin.maxmin.it record.
##

check_hosted_zone_has_record 'A' "${admin_dns_nm}"
has_admin_record="${__RESULT}"

if [[ 'true' == "${has_admin_record}" ]]
then
   echo 'WARN: found Admin web site record, deleting ...'

   delete_record 'A' "${admin_dns_nm}" "${admin_record_ip_addr}" 
   request_id="${__RESULT}"
                                 
   get_record_request_status "${request_id}"
   status="${__RESULT}"
   
   echo "Admin record deleted (${status})"
fi

# Create a record that points to the Admin website

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
target_admin_eip="${__RESULT}"

create_record 'A' "${admin_dns_nm}" "${target_admin_eip}"       
request_id="${__RESULT}"
                          
get_record_request_status "${request_id}"
status="${__RESULT}"
   
echo "Admin record ${admin_dns_nm} created (${status})."

echo
echo 'Hosted Zone created.'

