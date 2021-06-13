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

CRT_NM='maxmin-dev-elb-cert'

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
   echo '* WARN: Load Balancer instance not found'
else
   echo "* Load Balancer dns name: ${elb_dns}."
fi

cert_arn="$(get_server_certificate_arn "${CRT_NM}")"

if [[ -z "${cert_arn}" ]]
then
   echo '* WARN: certificate not found.'
else
   echo "* Load Balancer certificate: ${cert_arn}."
fi

sg_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -z "${sg_id}" ]]
then
   echo '* WARN: Security Group not found'
else
   echo "* Load Balancer Security Group ID: ${sg_id}."
fi

echo

##  
## Delete the instance.
##  
  
if [[ -n "${elb_dns}" ]]
then
   echo 'Deleting Load Balancer ...'
   
   delete_loadbalancer "${LBAL_NM}"
   
   ## Not found any other way to wait, it takes a lot to disappear,
   ## not able to delete the certificate until then.
   __wait  

   echo 'Load Balancer deleted.'
fi

## 
## Delete the server certificate in IAM.
## 
  
if [[ -n "${cert_arn}" ]]
then
   delete_server_certificate "${CRT_NM}"
   
   echo 'Load Balancer certificate deleted.'
fi

## 
## Delete the Security Group
## 

if [[ -n "${sg_id}" ]]
then
   granted="$(check_access_from_cidr_is_granted "${sg_id}" "${LBAL_PORT}" '0.0.0.0/0')"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_cidr "${sg_id}" "${LBAL_PORT}" '0.0.0.0/0'
   	
   	echo 'Revoked access from internet to the Load Balancer.'
   else
   	echo 'No internet access to the Load Balancer found.'
   fi
   
   delete_security_group "${sg_id}" 
   
   echo 'Load Balancer Security Group deleted.'
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/loadbalancer
mkdir "${TMP_DIR}"/loadbalancer

echo
echo 'Load Balancer deleted.'
echo 
