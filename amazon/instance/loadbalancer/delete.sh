#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

function __wait()
{
   count=0
   while [[ ${count} -lt 60 ]]; do
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

echo 'Deleting Load Balancer ...'

# Removing old files
rm -rf "${TMP_DIR:?}"/loadbalancer
mkdir "${TMP_DIR}"/loadbalancer

elb_dns="$(get_loadbalancer_dns_name "${LBAL_NM}")"
  
if [[ -z "${elb_dns}" ]]
then
   echo "'${LBAL_NM}' Load Balancer not found"
else
   echo "Deleting '${LBAL_NM}' Load Balancer ..."
   delete_loadbalancer "${LBAL_NM}"
   
   ## Not found any other way to wait, it takes a lot to disappear,
   ## not able to delete the certificate until then.
   __wait  

   echo "'${LBAL_NM}' Load Balancer deleted"
fi

## ******************
## Server Certificate
## ******************

cert_arn="$(get_server_certificate_arn "${LBAL_CRT_NM}")"
  
if [[ -z "${cert_arn}" ]]
then
   echo "'${LBAL_CRT_NM}' Load Balancer Certificate not found"
else
   delete_server_certificate "${LBAL_CRT_NM}"
   echo "'${LBAL_CRT_NM}' Load Balancer Certificate deleted"
fi

## **************
## Security Group
## **************

sg_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -z "${sg_id}" ]]
then
   echo "'${LBAL_SEC_GRP_NM}' Loadbalancer Security Group not found"
else
   granted="$(check_access_from_cidr_is_granted "${sg_id}" "${LBAL_PORT}" '0.0.0.0/0')"
   
   if [[ -n "${granted}" ]]
   then
   	revoke_access_from_cidr "${sg_id}" "${LBAL_PORT}" '0.0.0.0/0'
   	echo 'Revoked access to Loadbalancer'
   else
   	echo 'No access to Loadbalancer found'
   fi
   
   delete_security_group "${sg_id}" 
   echo "'${LBAL_SEC_GRP_NM}' Security Group deleted"
fi

echo 'Load Balancer components deleted'
echo

# Removing old files
rm -rf "${TMP_DIR:?}"/loadbalancer
mkdir "${TMP_DIR}"/loadbalancer


