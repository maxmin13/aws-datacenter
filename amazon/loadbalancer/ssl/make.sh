#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##
## Add an HTTPS listener to the load balancer on port 443 that forwards the requests to the 
## clients on port 8070 unencrypted.
## Remove the HTTP listener.
##

loadbalancer_dir='loadbalancer'

echo '*****************'
echo 'SSL load balancer'
echo '*****************'
echo

elb_dns="$(get_loadbalancer_dns_name "${LBAL_INST_NM}")"

if [[ -z "${elb_dns}" ]]
then
   echo '* ERROR: Load balancer box not found.'
   exit 1
else
   echo "* Load balancer DNS name: ${elb_dns}."
fi

sgp_id="$(get_security_group_id "${LBAL_INST_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: security group not found.'
   exit 1
else
   echo "* security group ID: ${sgp_id}."
fi

echo 

# Removing old files
rm -rf "${TMP_DIR:?}"/"${loadbalancer_dir}"
mkdir "${TMP_DIR}"/"${loadbalancer_dir}"

##
## Security group.
##

# Check HTTP access from the Internet.
granted_http="$(check_access_from_cidr_is_granted  "${sgp_id}" "${LBAL_INST_HTTP_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_http}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${LBAL_INST_HTTP_PORT}" '0.0.0.0/0'
   
   echo 'Revoked HTTP internet access to the load balancer.'
else
   echo 'WARN: HTTP internet access to the load balancer already revoked.'
fi

delete_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTP_PORT}"

echo 'HTTP listener deleted.'

delete_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}"

echo 'HTTPS listener deleted.'

## 
## SSL certificate
##

## The load balancer certificates are handled by AWS Identity and Access Management (IAM).

## TODO this is only dev, wrong place.
CRT_NM='maxmin-dev-elb-cert'
CRT_FILE='maxmin-dev-elb-cert.pem'
KEY_FILE='maxmin-dev-elb-key.pem'
CRT_COUNTRY_NM='IE'
CRT_PROVINCE_NM='Dublin'
CRT_CITY_NM='Dublin'
CRT_ORGANIZATION_NM='WWW'
CRT_UNIT_NM='UN'
CRT_COMMON_NM='www.maxmin.it'  

# Get the certificate ARN from IAM
cert_arn="$(get_server_certificate_arn "${CRT_NM}")"

if [[ -n "${cert_arn}" ]]
then 
   echo 'WARN: found certificate in IAM, deleting ...'
  
   # The certificate may still be locked by the deleted HTTPS listener, retry to delete it if fails.
   delete_server_certificate "${CRT_NM}" && echo 'Server certificate deleted.' ||
   {
      __wait 30
      delete_server_certificate "${CRT_NM}" && echo 'Server certificate deleted.' ||
      {
         __wait 30
         delete_server_certificate "${CRT_NM}" && echo 'Server certificate deleted.' ||
         {
            echo 'Error: deleting server certificate.'
            exit 1
         }
      }
   }
fi

# Wait until the certificate is removed from IAM.
cert_arn="$(get_server_certificate_arn "${CRT_NM}")"

test -z "${cert_arn}" && echo 'Certificated deleted.' || 
{  
   __wait 30
   cert_arn="$(get_server_certificate_arn "${CRT_NM}")"
   test -z "${cert_arn}" &&  echo 'Certificate deleted.' ||
   {
      __wait 30
      cert_arn="$(get_server_certificate_arn "${CRT_NM}")"
      test -z "${cert_arn}" &&  echo 'Certificate deleted.' || 
      {
         __wait 30
         cert_arn="$(get_server_certificate_arn "${CRT_NM}")"
         test -z "${cert_arn}" &&  echo 'Certificate deleted.' || 
         {
            # Throw an error if after 90 secs the cert is stil visible.
            echo 'ERROR: certificate not deleted from IAM.'
            exit 1     
         }       
      } 
   }
}
   
cd "${TMP_DIR}"/"${loadbalancer_dir}"

if [[ 'development' == "${ENV}" ]]
then
      # Create and upload a self-signed Server Certificate on IAM. 
 
      echo 'Creating self-signed SSL Certificate ...'

      # Generate RSA encrypted private key, protected with a passphrase.
      sed -e "s/SEDkey_fileSED/${KEY_FILE}/g" \
          -e "s/SEDkey_pwdSED/secret/g" \
             "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_rsa_template.exp > gen_rsa.sh

      echo 'gen_rsa.sh ready.'

      # Remove the password protection from the key file.
      sed -e "s/SEDkey_fileSED/${KEY_FILE}/g" \
          -e "s/SEDnew_key_fileSED/server.key.org/g" \
          -e "s/SEDkey_pwdSED/secret/g" \
             "${TEMPLATE_DIR}"/common/ssl/selfsigned/remove_passphase_template.exp > remove_passphase.sh   
      
      echo 'remove_passphase.sh ready.'

      # Create a self-signed Certificate.
      sed -e "s/SEDkey_fileSED/${KEY_FILE}/g" \
          -e "s/SEDcert_fileSED/${CRT_FILE}/g" \
          -e "s/SEDcountrySED/${CRT_COUNTRY_NM}/g" \
          -e "s/SEDstate_or_provinceSED/${CRT_PROVINCE_NM}/g" \
          -e "s/SEDcitySED/${CRT_CITY_NM}/g" \
          -e "s/SEDorganizationSED/${CRT_ORGANIZATION_NM}/g" \
          -e "s/SEDunit_nameSED/${CRT_UNIT_NM}/g" \
          -e "s/SEDcommon_nameSED/${CRT_COMMON_NM}/g" \
          -e "s/SEDemail_addressSED/${LBAL_EMAIL_ADD}/g" \
             "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_certificate_template.exp > gen_certificate.sh
             
      echo 'gen_certificate.sh ready.'
      
      cp "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_selfsigned_certificate.sh gen_selfsigned_certificate.sh
      
      echo 'gen_selfsigned_certificate.sh ready.'
      
      chmod +x gen_selfsigned_certificate.sh
      ./gen_selfsigned_certificate.sh > /dev/null
       
      echo 'Self-signed SSL certificate created.'

      # Upload to IAM.
      echo 'Uploading SSL certificate to IAM ...'

      upload_server_certificate "${CRT_NM}" \
          "${CRT_FILE}" \
          "${KEY_FILE}" \
          "${TMP_DIR}"/"${loadbalancer_dir}"  
else
      # TODO
      # TODO Use a certificate authenticated by a Certificate Authority.
      # TODO Enable SSLCertificateChainFile in ssl.conf
      # TODO  
   
      echo 'ERROR: a production certificate is not available, use a developement self-signed one.'
      
      exit 1
fi
    
# Wait until the certificate is available in IAM.
cert_arn="$(get_server_certificate_arn "${CRT_NM}")"

test -n "${cert_arn}" && echo 'Certificated uploaded.' || 
{  
   __wait 30
   cert_arn="$(get_server_certificate_arn "${CRT_NM}")"
   test -n "${cert_arn}" &&  echo 'Certificate uploaded.' ||
   {
      __wait 30
      cert_arn="$(get_server_certificate_arn "${CRT_NM}")"
      test -n "${cert_arn}" &&  echo 'Certificate uploaded.' || 
      {
         __wait 30
         cert_arn="$(get_server_certificate_arn "${CRT_NM}")"
         test -n "${cert_arn}" &&  echo 'Certificate uploaded.' || 
         {
            # Throw an error if after 90 secs the cert is stil not visible.
            echo 'ERROR: certificate not uploaded to IAM.'
            exit 1     
         }       
      } 
   }
}

cert_arn="$(get_server_certificate_arn "${CRT_NM}")"

# Create listener is idempotent, we can skip checking if the listener exists.
# Even if the iam command list-server-certificates has returned the certificate arn, the cert may 
# not still be available, add listener may fail if called too early. 
add_https_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" "${cert_arn}" && 
echo 'HTTPS listener added.' ||
{
   __wait 30
   add_https_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" "${cert_arn}" && 
   echo 'HTTPS listener added.' ||
   {
      echo 'ERROR: adding HTTPS listener.'
      exit 1
   }
}

# Check HTTPS access from the Internet.
granted_https="$(check_access_from_cidr_is_granted  "${sgp_id}" "${LBAL_INST_HTTPS_PORT}" '0.0.0.0/0')"

if [[ -z "${granted_https}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${LBAL_INST_HTTPS_PORT}" '0.0.0.0/0'
   
   echo 'Granted HTTPS internet access to the load balancer.'
else
   echo 'WARN: HTTPS internet access to the load balancer already granted.'
fi

loadbalancer_dns="$(get_loadbalancer_dns_name "${LBAL_INST_NM}")"

# Clear local files
rm -rf "${TMP_DIR:?}"/"${loadbalancer_dir}"

echo
echo "Load Balancer up and running at: ${loadbalancer_dns}."
echo



