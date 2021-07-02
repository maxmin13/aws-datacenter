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
## Create a load balancer that listens on port 443 HTTPS port and forwards the requests to the clients on port 80 HTTP unencrypted.
## The load balancer performs healt-checks of the registered instances. To be marked as healty, the monitored instances must provide 
## the following endpoint to the Load Balancer, ex: HTTP:"8090/elb.htm, the endpoint must return 'ok' response. 
## Check security group permissions and security module override rules.
## If Elastic Load Balancing finds an unhealthy instance, it stops sending traffic to the instance and routes traffic to the healthy instances. 
## The load balancer is usable as soon as any one of your registered instances is in the InService state.
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
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

subnet_ids="$(get_subnet_ids "${dtc_id}")"

if [[ -z "${subnet_ids}" ]]
then
   echo '* ERROR: subnets not found.'
   exit 1
else
   echo "* subnet IDs: ${subnet_ids}."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${loadbalancer_dir}"
mkdir "${TMP_DIR}"/"${loadbalancer_dir}"

## 
## Security group 
## 

sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the load balancer security group is already created.'
else
   sgp_id="$(create_security_group "${dtc_id}" "${LBAL_SEC_GRP_NM}" 'Load balancer security group.')"  
   
   echo 'Created load balancer security group.'
fi

granted_https="$(check_access_from_cidr_is_granted  "${sgp_id}" "${LBAL_HTTPS_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_https}" ]]
then
   echo 'WARN: Internet access to the load balancer already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${LBAL_HTTPS_PORT}" '0.0.0.0/0'
   
   echo 'Granted HTTPS access to the load balancer from anywhere in the Internet.'
fi

## 
## SSL certificate
##

## The load balancer certificates are handled by AWS Identity and Access Management (IAM).

cert_arn="$(get_server_certificate_arn "${CRT_NM}")"

if [[ -n "${cert_arn}" ]]
then 
   echo 'WARN: load balancer certificate already uploaded to IAM.'
else
   #if [[ 'development' == "${ENV}" ]]
   if 'true'
   then
   (
      # Create and upload a self-signed Server Certificate on IAM. 
   
      cd "${TMP_DIR}"/"${loadbalancer_dir}"
   
      echo 'Creating self-signed SSL Certificate ...'

      # Generate RSA encrypted private key, protected with a passphrase.
      sed -e "s/SEDkey_fileSED/server.key/g" \
          -e "s/SEDkey_pwdSED/${LBAL_PK_PWD}/g" \
             "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_rsa_template.exp > gen_rsa.sh

      chmod +x gen_rsa.sh
      ./gen_rsa.sh > /dev/null
      rm -f gen_rsa.sh
   
      echo 'SSL key-pair created.'

      # Remove the password protection from the key file.
      sed -e "s/SEDkey_fileSED/server.key/g" \
          -e "s/SEDnew_key_fileSED/server.key.org/g" \
          -e "s/SEDkey_pwdSED/${LBAL_PK_PWD}/g" \
             "${TEMPLATE_DIR}"/common/ssl/selfsigned/remove_passphase_template.exp > remove_passphase.sh   
      
      chmod +x remove_passphase.sh
      ./remove_passphase.sh > /dev/null
      rm -f remove_passphase.sh  
   
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
             "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_certificate_template.exp > gen_certificate.sh
      
      chmod +x gen_certificate.sh
      ./gen_certificate.sh > /dev/null
      rm -f gen_certificate.sh
   
      echo 'Self-signed SSL certificate created.'

      mv server.key "${KEY_FILE}"
      mv server.crt "${CRT_FILE}"

      # Upload to IAM
      echo 'Uploading SSL certificate to IAM ...'
   
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
## Load balancer box
## 

exists="$(get_loadbalancer_dns_name "${LBAL_NM}")"

if [[ -n "${exists}" ]]
then
   echo "WARN: load balancer box already created."
else
   echo 'Creating the load balancer box ...'
   
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
