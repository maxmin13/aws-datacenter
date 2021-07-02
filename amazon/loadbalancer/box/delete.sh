#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

function __wait()
{
   count=0
   while [[ ${count} -lt 90 ]]; do
      count=$((count+3))
      printf '.'
      sleep 3
   done
   printf '\n'
}

echo '*************'
echo 'Load balancer'
echo '*************'
echo

elb_dns="$(get_loadbalancer_dns_name "${LBAL_NM}")"

if [[ -z "${elb_dns}" ]]
then
   echo '* WARN: load balancer box not found.'
else
   echo "* DNS name: ${elb_dns}."
fi

sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found'
else
   echo "* security group ID: ${sgp_id}."
fi

echo

##  
## Delete the instance.
##  
  
if [[ -n "${elb_dns}" ]]
then
   echo 'Deleting load balancer ...'
   
   delete_loadbalancer "${LBAL_NM}"
   
   echo 'Load balancer deleted.'
fi

## 
## Delete the security group
## 

# TODO webphp box grants access to 8080 (healt-check) and 8070 (website) to the load balancer, remove this before the group.

if [[ -n "${sgp_id}" ]]
then
   granted="$(check_access_from_cidr_is_granted "${sgp_id}" "${LBAL_HTTPS_PORT}" '0.0.0.0/0')"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_cidr "${sgp_id}" "${LBAL_HTTPS_PORT}" '0.0.0.0/0'
   	
   	echo 'Revoked access from internet to the load balancer.'
   else
   	echo 'No internet access to the load balancer found.'
   fi
   
   __wait 
   delete_security_group "${sgp_id}" 
   
   echo 'Load balancer security group deleted.'
   echo
fi

 
