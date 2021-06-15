#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

CRT_NM='maxmin-dev-elb-cert'
CRT_FILE='maxmin-dev-elb-cert.pem'
KEY_FILE='maxmin-dev-elb-key.pem'
CHAIN_FILE='maxmin-dev-elb-chain.pem'
CRT_COUNTRY_NM='IE'
CRT_PROVINCE_NM='Dublin'
CRT_CITY_NM='Dublin'
CRT_COMPANY_NM='maxmin13'
CRT_ORGANIZATION_NM='WWW'
CRT_UNIT_NM='UN'
CRT_COMMON_NM='www.maxmin.it'

##
## Create a Load Balancer that listens on port 443 HTTPS port and forwards the requests to the clients on port 80 HTTP unencrypted.
## The Load Balancer performs healt-checks of the registered instances. To be marked as healty, the monitored instances must provide 
## the following endpoint to the Load Balancer, ex: HTTP:"8090/elb.htm, the endpoint must return 'ok' response. 
## Check Security Group permissions and security module override rules.
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

loadbalancer_dir='loadbalancer'

echo '*************'
echo 'Load balancer'
echo '*************'
echo

dtc_id="$(get_datacenter_id "${DTC_NM}")"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: Data Center not found.'
   exit 1
else
   echo "* Data Center ID: ${dtc_id}."
fi

subnet_ids="$(get_subnet_ids "${dtc_id}")"

if [[ -z "${subnet_ids}" ]]
then
   echo '* ERROR: subnets not found.'
   exit 1
else
   echo "* Subnet IDs: ${subnet_ids}."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${loadbalancer_dir}"
mkdir "${TMP_DIR}"/"${loadbalancer_dir}"

## 
## Security Group 
## 

sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Load Balancer Security Group is already created.'
else
   sgp_id="$(create_security_group "${dtc_id}" "${LBAL_SEC_GRP_NM}" 'Load Balancer Security Group')"  
   
   echo 'Created Load Balancer Security Group.'
fi

granted_https="$(check_access_from_cidr_is_granted  "${sgp_id}" "${LBAL_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_https}" ]]
then
   echo 'WARN: Internet access to the Load Balancer already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${LBAL_PORT}" '0.0.0.0/0'
   
   echo 'Granted HTTPS access to the Load Balancer from anywhere in the Internet.'
fi

## 
## SSL certificate
##

## The Load Balancer certificates are handled by AWS Identity and Access Management (IAM).

cert_arn="$(get_server_certificate_arn "${CRT_NM}")"

if [[ -n "${cert_arn}" ]]
then 
   echo 'WARN: Load Balancer certificate already uploaded to IAM.'
else
   #if [[ 'development' == "${ENV}" ]]
   if 'true'
   then
   (
      # Create and upload a self-signed Server Certificate on IAM. 
   
      cd "${TMP_DIR}"/"${loadbalancer_dir}"
   
      echo 'Creating self-signed Load Balancer Certificate ...'

      # Generate RSA encrypted private key, protected with a passphrase.
      sed -e "s/SEDkey_fileSED/server.key/g" \
          -e "s/SEDkey_pwdSED/${LBAL_PK_PWD}/g" \
             "${TEMPLATE_DIR}"/common/ssl/self_signed/gen-rsa_template.exp > gen-rsa.sh

      chmod +x gen-rsa.sh
      ./gen-rsa.sh > /dev/null
      rm -f gen-rsa.sh
   
      echo 'Key-pair created.'

      # Remove the password protection from the key file.
      sed -e "s/SEDkey_fileSED/server.key/g" \
          -e "s/SEDnew_key_fileSED/server.key.org/g" \
          -e "s/SEDkey_pwdSED/${LBAL_PK_PWD}/g" \
             "${TEMPLATE_DIR}"/common/ssl/self_signed/remove-passphase_template.exp > remove-passphase.sh   
      
      chmod +x remove-passphase.sh
      ./remove-passphase.sh > /dev/null
      rm -f remove-passphase.sh  
   
      echo 'Removed password protection.'

      rm -f server.key
      mv server.key.org server.key

      # Create a self-signed Certificate.
      sed -e "s/SEDkey_fileSED/server.key/g" \
          -e "s/SEDcert_fileSED/server.crt/g" \
          -e "s/SEDcountrySED/${CRT_COUNTRY_NM}/g" \
          -e "s/SEDstate_or_provinceSED/${CRT_PROVINCE_NM}/g" \
          -e "s/SEDcitySED/${CRT_CITY_NM}/g" \
          -e "s/SEDorganizationSED/${CRT_ORGANIZATION_NM}/g" \
          -e "s/SEDunit_nameSED/${CRT_UNIT_NM}/g" \
          -e "s/SEDcommon_nameSED/${CRT_COMMON_NM}/g" \
          -e "s/SEDemail_addressSED/${LBAL_EMAIL_ADD}/g" \
             "${TEMPLATE_DIR}"/common/ssl/self_signed/gen-selfsign-cert_template.exp > gen-selfsign-cert.sh
      
      chmod +x gen-selfsign-cert.sh
      ./gen-selfsign-cert.sh > /dev/null
      rm -f gen-selfsign-cert.sh
   
      echo 'Self-signed Load Balancer certificate created.'

      mv server.key "${KEY_FILE}"
      mv server.crt "${CRT_FILE}"

      # Upload to IAM
      echo 'Uploading certificate to IAM ...'
   
      upload_server_certificate "${CRT_NM}" \
          "${CRT_FILE}" \
          "${KEY_FILE}" \
          "${TMP_DIR}"/"${loadbalancer_dir}"
     
      __wait
   
      echo 'Load Balancer certificate uploaded to IAM.'

      rm -f "${KEY_FILE:?}"
      rm -f "${CRT_FILE:?}"
   )
   #elif [[ 'production' == "${ENV}" ]]
   #then
   else
   (
      # TODO
      # TODO Use a certificate authenticated by a Certificate Authority.
      # TODO Enable SSLCertificateChainFile in ssl.conf
      # TODO  
   
      echo 'ERROR: a production certificate is not available, use a developement self-signed one.'
      
      exit 1
   )
   fi
fi

## 
## Load Balancer box
## 

exists="$(get_loadbalancer_dns_name "${LBAL_NM}")"

if [[ -n "${exists}" ]]
then
   echo "WARN: Load Balancer box already created."
else
   echo 'Creating the Load Balancer box ...'
   
   # Get the certificate ARN from IAM
   cert_arn="$(get_server_certificate_arn "${CRT_NM}")"
   create_loadbalancer "${LBAL_NM}" "${cert_arn}" "${sgp_id}" "${subnet_ids}"
   configure_loadbalancer_health_check "${LBAL_NM}"

   echo "Load Balancer box created."
fi  
       
loadbalancer_dns="$(get_loadbalancer_dns_name "${LBAL_NM}")"

# Removing old local files
rm -rf "${TMP_DIR:?}"/"${loadbalancer_dir}"

echo
echo "Load Balancer up and running at: ${loadbalancer_dns}."
echo
