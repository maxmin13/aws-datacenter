#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

function __wait()
{
   count=0
   while [[ ${count} -lt 70 ]]; do
      count=$((count+3))
      printf '.'
      sleep 3
   done
   printf '\n'
}

echo '*************'
echo 'Load Balancer'
echo '*************'
echo

# Removing old files
rm -rf "${TMP_DIR:?}"/loadbalancer
mkdir "${TMP_DIR}"/loadbalancer

elb_dns="$(get_loadbalancer_dns_name "${LBAL_NM}")"

if [[ -z "${elb_dns}" ]]
then
   echo '* WARN: load balancer instance not found'
else
   echo "* load balancer dns name: '${elb_dns}'"
fi

cert_arn="$(get_server_certificate_arn "${LBAL_CRT_NM}")"

if [[ -z "${cert_arn}" ]]
then
   echo '* WARN: security certificate not found'
else
   echo "* load balancer security certificate: '${cert_arn}'"
fi

sg_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -z "${sg_id}" ]]
then
   echo '* WARN: security group not found'
else
   echo "* load balancer security group ID: '${sg_id}'"
fi

echo

##  
## Delete the instance.
##  
  
if [[ -n "${elb_dns}" ]]
then
   echo 'Deleting load balancer ...'
   delete_loadbalancer "${LBAL_NM}"
   
   ## Not found any other way to wait, it takes a lot to disappear,
   ## not able to delete the certificate until then.
   __wait  

   echo 'Load balancer deleted'
fi

## 
## Delete the server certificate
## 
  
if [[ -n "${cert_arn}" ]]
then
   delete_server_certificate "${LBAL_CRT_NM}"
   echo 'Load balancer certificate deleted'
fi

## 
## Delete the security group
## 

if [[ -n "${sg_id}" ]]
then
   granted="$(check_access_from_cidr_is_granted "${sg_id}" "${LBAL_PORT}" '0.0.0.0/0')"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_cidr "${sg_id}" "${LBAL_PORT}" '0.0.0.0/0'
   	echo 'Revoked access from internet to the load balancer'
   else
   	echo 'No internet access to the load balancer found'
   fi
   
   delete_security_group "${sg_id}" 
   echo 'Load balancer security group deleted'
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/loadbalancer
mkdir "${TMP_DIR}"/loadbalancer


