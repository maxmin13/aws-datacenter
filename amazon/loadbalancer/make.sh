#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##
## Create a Load Balancer that listens on port 443 HTTPS port and forwards the requests to the clients on port 80 HTTP unencrypted.
## The Load Balancer performs healt-checks of the registered instances. To be marked as healty, the monitored instances must provide 
## the following endpoint to the Load Balancer, ex: HTTP:"8090/elb.htm, the endpoint must return 'ok' response. 
## Check security group permissions and security module override rules.
## If Elastic Load Balancing finds an unhealthy instance, it stops sending traffic to the instance and routes traffic to the healthy instances. 
## The Load Balancer is usable as soon as any one of your registered instances is in the InService state.
##

function __wait()
{
   count=0
   while [[ ${count} -lt 15 ]]; do
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

loadbalancer_dns="$(get_loadbalancer_dns_name "${LBAL_NM}")"

if [[ -n "${loadbalancer_dns}" ]]
then
   echo '* ERROR: the load balancer is already created'
   exit 1
fi

vpc_id="$(get_vpc_id "${VPC_NM}")"
  
if [[ -z "${vpc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: '${vpc_id}'"
fi

subnet_ids="$(get_subnet_ids "${vpc_id}")"

if [[ -z "${subnet_ids}" ]]
then
   echo '* ERROR: subnets not found.'
   exit 1
else
   echo "* subnet IDs: '${subnet_ids}'"
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/loadbalancer
mkdir "${TMP_DIR}"/loadbalancer

## 
## Security group
## 

sg_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"
  
if [[ -n "${sg_id}" ]]
then
   echo 'ERROR: the load balancer security group is already created'
   exit 1
fi

sg_id="$(create_security_group "${vpc_id}" "${LBAL_SEC_GRP_NM}" 'Load balancer security group')"
echo 'Load balancer security group created'
allow_access_from_cidr "${sg_id}" "${LBAL_PORT}" '0.0.0.0/0'
echo 'Granted HTTPS access to the load balancer from anywhere in the Internet'

## 
## SSL certificate
##

cert_arn="$(get_server_certificate_arn "${LBAL_CRT_NM}")"

if [[ -n "${cert_arn}" ]]
then
   echo 'Deleting previous load balancer certificate ...' 
   delete_server_certificate "${LBAL_CRT_NM}"
   echo 'Load balancer certificate deleted'
fi

#if [[ 'development' == "${ENV}" ]]
if 'true'
then
(
   # Create and upload self-signed Server Certificate 
   
   cd "${TMP_DIR}"/loadbalancer
   echo 'Creating self-signed Load Balancer Certificate ...'

   # Generate RSA encrypted private key, protected with a passphrase.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDkey_pwdSED/${LBAL_PK_PWD}/g" \
    "${TEMPLATE_DIR}"/ssl/gen-rsa_template.exp > gen-rsa.sh

   chmod +x gen-rsa.sh
   ./gen-rsa.sh > /dev/null
   rm -f gen-rsa.sh
   echo 'Primary key created'

   # Remove the password protection from the key file.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDnew_key_fileSED/server.key.org/g" \
       -e "s/SEDkey_pwdSED/${LBAL_PK_PWD}/g" \
          "${TEMPLATE_DIR}"/ssl/remove-passphase_template.exp > remove-passphase.sh   
      
   chmod +x remove-passphase.sh
   ./remove-passphase.sh > /dev/null
   rm -f remove-passphase.sh  
   echo 'Removed password protection'

   rm -f server.key
   mv server.key.org server.key

   # Create a self-signed Certificate.
   sed -e "s/SEDkey_fileSED/server.key/g" \
       -e "s/SEDcert_fileSED/server.crt/g" \
       -e "s/SEDcountrySED/${LBAL_CRT_COUNTRY_NM}/g" \
       -e "s/SEDstate_or_provinceSED/${LBAL_CRT_PROVINCE_NM}/g" \
       -e "s/SEDcitySED/${LBAL_CRT_CITY_NM}/g" \
       -e "s/SEDorganizationSED/${LBAL_CRT_ORGANIZATION_NM}/g" \
       -e "s/SEDunit_nameSED/${LBAL_CRT_UNIT_NM}/g" \
       -e "s/SEDcommon_nameSED/${LBAL_CRT_COMMON_NM}/g" \
       -e "s/SEDemail_addressSED/${LBAL_EMAIL_ADD}/g" \
          "${TEMPLATE_DIR}"/ssl/gen-selfsign-cert_template.exp > gen-selfsign-cert.sh
      
   chmod +x gen-selfsign-cert.sh
   ./gen-selfsign-cert.sh > /dev/null
   rm -f gen-selfsign-cert.sh
   echo 'Self-signed load balancer certificate created'

   mv 'server.key' "${LBAL_KEY_FILE}"
   mv 'server.crt' "${LBAL_CRT_FILE}"
   
   # Print the certificate to the console
   # openssl x509 -in "${LBAL_CRT_FILE}" -text -noout  >> "${LOG_DIR}/loadbalancer.log"
   
   # Upload to IAM
   echo 'Uploading the certificate to the load balancer ...'
   upload_server_certificate "${LBAL_CRT_NM}" \
                             "${LBAL_CRT_FILE}" \
                             "${LBAL_KEY_FILE}" \
                             "${TMP_DIR}"/loadbalancer
   __wait
   
   echo 'Uploaded the self-signed certificate to the load balancer'

   rm -f "${LBAL_KEY_FILE:?}"
   rm -f "${LBAL_CRT_FILE:?}"
)
#elif [[ 'production' == "${ENV}" ]]
#then
else
(
   # TODO
   # TODO Use a certificate authenticated by a Certificate Authority.
   # TODO Enable SSLCertificateChainFile in ssl.conf
   # TODO  
   
   echo 'Error: a production certificate is not available, use a developement self-signed one'
   exit 1
)
fi

##  
## Instance
## 

echo 'Creating the load balancer ....'

cert_arn="$(get_server_certificate_arn "${LBAL_CRT_NM}")"
create_loadbalancer "${LBAL_NM}" "${cert_arn}" "${sg_id}" "${subnet_ids}"
configure_loadbalancer_health_check "${LBAL_NM}"
loadbalancer_dns_nm="$(get_loadbalancer_dns_name "${LBAL_NM}")"

echo "Load Balancer created and available at: ${loadbalancer_dns_nm}"

# Removing old local files
rm -rf "${TMP_DIR:?}"/loadbalancer

echo
