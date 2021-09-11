#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*************'
echo 'Load balancer'
echo '*************'
echo

### TODO: not the right place, only for dev.
CRT_NM='maxmin-dev-elb-cert'

get_instance_id "${ADMIN_INST_NM}"
admin_instance_id="${__RESULT}"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${admin_instance_id} (${instance_st})."
fi

get_loadbalancer_dns_name "${LBAL_INST_NM}"
lbal_dns="${__RESULT}"

if [[ -z "${lbal_dns}" ]]
then
   echo '* WARN: load balancer box not found.'
else
   echo "* DNS name: ${lbal_dns}."
fi

get_security_group_id "${LBAL_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found'
else
   echo "* security group ID: ${sgp_id}."
fi

get_server_certificate_arn "${CRT_NM}" > /dev/null
cert_arn="${__RESULT}"

if [[ -z "${cert_arn}" ]]
then
   echo '* WARN: SSL certificate not found.'
else
   echo "* SSL certificate: ${cert_arn}."
fi

echo

##  
## Delete the instance.
##  
  
if [[ -n "${lbal_dns}" ]]
then
   echo 'Deleting load balancer box ...'
   
   delete_loadbalancer "${LBAL_INST_NM}"
   
   echo 'Load balancer box deleted.'
fi

## 
## Delete the security group
## 

# TODO webphp box grants access to 8080 (healt-check) and 8070 (website) to the load balancer, 
#      remove these dependencies before the group.
if [[ -n "${sgp_id}" ]]
then
   echo 'Deleting security group ...'
   
   # If deleted too quickly after deleting the loadb alancer, the security group has still 
   # dependent objects.
   # shellcheck disable=SC2015
   delete_security_group "${sgp_id}" > /dev/null 2>&1 && echo 'Security group deleted.' || 
   {
      __wait 70
      delete_security_group "${sgp_id}" > /dev/null 2>&1 && echo 'Security group deleted.' || 
      {
         __wait 40
         delete_security_group "${sgp_id}" > /dev/null 2>&1 && echo 'Security group deleted.' || 
         {
            __wait 20
            delete_security_group "${sgp_id}" > /dev/null 2>&1 && echo 'Security group deleted.' || 
            {
               echo 'ERROR: deleting security group.'
               exit 1
            }
         }
      } 
   }
fi

## 
## Delete the server certificate in IAM.
## 
  
if [[ -n "${cert_arn}" ]]
then
   echo 'Deleting certificate ...'

   delete_server_certificate "${CRT_NM}"
fi
  
echo

 
