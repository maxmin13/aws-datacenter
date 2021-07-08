#!/bin/bash

# shellcheck disable=SC2034

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##
## Add an HTTPS listener to the load balancer on port 443 that forwards the requests to the 
## clients on port 8070 unencrypted.
## Remove the HTTP listener.
##

lbal_dir='loadbalancer'

echo '*****************'
echo 'SSL load balancer'
echo '*****************'
echo

lbal_dns="$(get_loadbalancer_dns_name "${LBAL_INST_NM}")"

if [[ -z "${lbal_dns}" ]]
then
   echo '* ERROR: Load balancer box not found.'
   exit 1
else
   echo "* Load balancer DNS name: ${lbal_dns}."
fi

lbal_sgp_id="$(get_security_group_id "${LBAL_INST_SEC_GRP_NM}")"

if [[ -z "${lbal_sgp_id}" ]]
then
   echo '* ERROR: load balancer security group not found.'
   exit 1
else
   echo "* load balancer security group ID: ${lbal_sgp_id}."
fi

if [[ 'production' == "${ENV}" ]]
then
   admin_instance_id="$(get_instance_id "${ADMIN_INST_NM}")"

   if [[ -z "${admin_instance_id}" ]]
   then
      echo '* ERROR: Admin box not found.'
      exit 1
   else
      admin_instance_st="$(get_instance_state "${ADMIN_INST_NM}")"
      echo "* Admin box ID: ${admin_instance_id} (${admin_instance_st})."
   fi   
   
   admin_sgp_id="$(get_security_group_id "${ADMIN_INST_SEC_GRP_NM}")"

   if [[ -z "${admin_sgp_id}" ]]
   then
      echo '* ERROR: Admin security group not found.'
      exit 1
   else
      echo "* Admin security group ID: ${admin_sgp_id}."
   fi 
   
   admin_eip="$(get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}")"

   if [[ -z "${admin_eip}" ]]
   then
      echo '* ERROR: Admin public IP address not found.'
      exit 1
   else
      echo "* Admin public IP address: ${admin_eip}."
   fi     
fi

echo 

# Removing old files
rm -rf "${TMP_DIR:?}"/"${lbal_dir}"
mkdir "${TMP_DIR}"/"${lbal_dir}"

##
## Security group.
##

# Check HTTP access from the Internet to the load balancer.
granted_lbal_http="$(check_access_from_cidr_is_granted  "${lbal_sgp_id}" "${LBAL_INST_HTTP_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_lbal_http}" ]]
then
   revoke_access_from_cidr "${lbal_sgp_id}" "${LBAL_INST_HTTP_PORT}" '0.0.0.0/0'
   
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

if [[ 'production' == "${ENV}" ]]
then
   crt_nm='maxmin-dev-elb-cert'
   crt_file='maxmin-dev-elb-cert.pem'
   key_file='maxmin-dev-elb-key.pem'
   GIT_ACME_DNS_URL='https://github.com/joohoi/acme-dns' 
   ACME_DNS_CONFIG_FILE='config.cfg'   
else
   crt_nm='maxmin-dev-elb-cert'
   crt_file='maxmin-dev-elb-cert.pem'
   key_file='maxmin-dev-elb-key.pem'
   CRT_COUNTRY_NM='IE'
   CRT_PROVINCE_NM='Dublin'
   CRT_CITY_NM='Dublin'
   CRT_ORGANIZATION_NM='WWW'
   CRT_UNIT_NM='UN'
   CRT_COMMON_NM='www.maxmin.it'  
fi

# Get the certificate ARN from IAM
cert_arn="$(get_server_certificate_arn "${crt_nm}")"

if [[ -n "${cert_arn}" ]]
then 
   echo 'WARN: found certificate in IAM, deleting ...'
  
   # The certificate may still be locked by the deleted HTTPS listener, retry to delete it error.
   # shellcheck disable=SC2015
   delete_server_certificate "${crt_nm}" && echo 'Server certificate deleted.' ||
   {
      __wait 30
      delete_server_certificate "${crt_nm}" && echo 'Server certificate deleted.' ||
      {
         __wait 30
         delete_server_certificate "${crt_nm}" && echo 'Server certificate deleted.' ||
         {
            echo 'Error: deleting server certificate.'
            exit 1
         }
      }
   }
fi

# Wait until the certificate is removed from IAM.
cert_arn="$(get_server_certificate_arn "${crt_nm}")"
# shellcheck disable=SC2015
test -z "${cert_arn}" && echo 'Certificated deleted.' || 
{  
   __wait 30
   cert_arn="$(get_server_certificate_arn "${crt_nm}")"
   test -z "${cert_arn}" &&  echo 'Certificate deleted.' ||
   {
      __wait 30
      cert_arn="$(get_server_certificate_arn "${crt_nm}")"
      test -z "${cert_arn}" &&  echo 'Certificate deleted.' || 
      {
         __wait 30
         cert_arn="$(get_server_certificate_arn "${crt_nm}")"
         test -z "${cert_arn}" &&  echo 'Certificate deleted.' || 
         {
            # Throw an error if after 90 secs the cert is stil visible.
            echo 'ERROR: certificate not deleted from IAM.'
            exit 1     
         }       
      } 
   }
}
   
cd "${TMP_DIR}"/"${lbal_dir}"

if [[ 'development' == "${ENV}" ]]
then

   #
   # Create and upload a self-signed Server Certificate to IAM. 
   #
 
   echo 'Creating self-signed SSL Certificate ...'

   # Generate RSA encrypted private key, protected with a passphrase.
   sed -e "s/SEDkey_fileSED/${key_file}/g" \
       -e "s/SEDkey_pwdSED/secret/g" \
          "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_rsa_template.exp > gen_rsa.sh

   echo 'gen_rsa.sh ready.'

   # Remove the password protection from the key file.
   sed -e "s/SEDkey_fileSED/${key_file}/g" \
       -e "s/SEDnew_key_fileSED/server.key.org/g" \
       -e "s/SEDkey_pwdSED/secret/g" \
          "${TEMPLATE_DIR}"/common/ssl/selfsigned/remove_passphase_template.exp > remove_passphase.sh   
      
   echo 'remove_passphase.sh ready.'

   # Create a self-signed Certificate.
   sed -e "s/SEDkey_fileSED/${key_file}/g" \
       -e "s/SEDcert_fileSED/${crt_file}/g" \
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
   ./gen_selfsigned_certificate.sh 
       
   echo 'Self-signed SSL certificate created.'

   # Upload to IAM.
   echo 'Uploading SSL certificate to IAM ...'

   upload_server_certificate "${crt_nm}" \
       "${crt_file}" \
       "${key_file}" \
       "${TMP_DIR}"/"${lbal_dir}"  
else

   #
   # Install an acme-dns server in the Admin instance to run the DNS-01 certbot challenge.
   #
     
   # SSH Access to Admin instance.
   granted_admin_ssh="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" '0.0.0.0/0')"

   if [[ -n "${granted_admin_ssh}" ]]
   then
      echo 'WARN: SSH access to the Admin box already granted.'
   else
      allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" '0.0.0.0/0'
   
      echo 'Granted SSH access to the Admin box.'
   fi
   
   # Upload the scripts to the Admin box.

   echo 'Uploading the scripts to the Admin box ...'

   remote_dir=/home/"${ADMIN_INST_USER_NM}"/script

   key_pair_file="$(get_keypair_file_path "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}")"
   wait_ssh_started "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

   ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
       "${key_pair_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"     
   
   sed -e "s/SEDacme_dns_urlSED/${GIT_ACME_DNS_URL}/g" \
       -e "s/SEDacme_dns_server_ip_addSED/${admin_eip}/g" \
       -e "s/SEDacme_dns_config_fileSED/${ACME_DNS_CONFIG_FILE}/g" \
          "${TEMPLATE_DIR}"/common/ssl/ca/install_acme_dns_server_template.sh > install_acme_dns_server.sh     
  
   echo 'install_acme_dns_server.sh ready.' 
   
   scp_upload_file "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${lbal_dir}"/install_acme_dns_server.sh   
    
    
   # config.cfg  
    
    exit 11
        
fi
    
# Wait until the certificate is visible in IAM.
cert_arn="$(get_server_certificate_arn "${crt_nm}")"
# shellcheck disable=SC2015
test -n "${cert_arn}" && echo 'Certificated uploaded.' || 
{  
   __wait 30
   cert_arn="$(get_server_certificate_arn "${crt_nm}")"
   test -n "${cert_arn}" &&  echo 'Certificate uploaded.' ||
   {
      __wait 30
      cert_arn="$(get_server_certificate_arn "${crt_nm}")"
      test -n "${cert_arn}" &&  echo 'Certificate uploaded.' || 
      {
         __wait 30
         cert_arn="$(get_server_certificate_arn "${crt_nm}")"
         test -n "${cert_arn}" &&  echo 'Certificate uploaded.' || 
         {
            # Throw an error if after 90 secs the cert is stil not visible.
            echo 'ERROR: certificate not uploaded to IAM.'
            exit 1     
         }       
      } 
   }
}

cert_arn="$(get_server_certificate_arn "${crt_nm}")"

# Create listener is idempotent, we can skip checking if the listener exists.
# Even if the IAM command list-server-certificates has returned the certificate ARN, the certificate 
# may still not be available and add listener command may fail if called too early. 
# shellcheck disable=SC2015
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

# Check HTTPS access from the Internet to the load balancer.
granted_https="$(check_access_from_cidr_is_granted  "${lbal_sgp_id}" "${LBAL_INST_HTTPS_PORT}" '0.0.0.0/0')"

if [[ -z "${granted_https}" ]]
then
   allow_access_from_cidr "${lbal_sgp_id}" "${LBAL_INST_HTTPS_PORT}" '0.0.0.0/0'
   
   echo 'Granted HTTPS internet access to the load balancer.'
else
   echo 'WARN: HTTPS internet access to the load balancer already granted.'
fi

lbal_dns="$(get_loadbalancer_dns_name "${LBAL_INST_NM}")"

# Clear local files
rm -rf "${TMP_DIR:?}"/"${lbal_dir}"

echo
echo "Load Balancer up and running at: ${lbal_dns}."
echo



