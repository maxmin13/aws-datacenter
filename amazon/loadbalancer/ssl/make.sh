#!/bin/bash

# shellcheck disable=SC2034

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
shopt -s inherit_errexit

########################################################################
## The script configure SSL in the load balancer.
## It adds an HTTPS listener to the load balancer on port 443 that   
## forwards the requests to the webphp websites on port 8070 unencrypted  
## and remove the HTTP listener. 
## The script uploads an SSL certificate to IAM. In development the 
## certificate is self-signed, in production the certificate is signed 
## by Let's Encrypt certificate authority.
########################################################################

crt_entity_nm='lbal_certificate'

if [[ 'production' == "${ENV}" ]]
then
   crt_file_nm='www.maxmin.it.cer'
   key_file_nm='www.maxmin.it.key'
   full_chain_file_nm='fullchain.cer'
else
   crt_file_nm='www.dev.maxmin.it.cer'  
fi

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
   get_instance_id "${ADMIN_INST_NM}"
   admin_instance_id="${__RESULT}"

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
mkdir -p "${TMP_DIR}"/"${lbal_dir}"

##
## Security group.
##

# Check HTTP access from the Internet to the load balancer.
granted_lbal_http="$(check_access_from_cidr_is_granted  "${lbal_sgp_id}" "${LBAL_INST_HTTP_PORT}" 'tcp' '0.0.0.0/0')"

if [[ -n "${granted_lbal_http}" ]]
then
   revoke_access_from_cidr "${lbal_sgp_id}" "${LBAL_INST_HTTP_PORT}" 'tcp' '0.0.0.0/0' > /dev/null
   
   echo 'Revoked HTTP internet access to the load balancer.'
else
   echo 'WARN: HTTP internet access to the load balancer already revoked.'
fi

##
## HTTP listener.
##

delete_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTP_PORT}"

echo 'HTTP listener deleted.'

delete_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}"

echo 'HTTPS listener deleted.'

## 
## IAM SSL certificate
##

## The load balancer certificates are handled by AWS Identity and Access Management (IAM).

# Check if a certificate is alread uploaded to IAM
get_server_certificate_arn "${crt_entity_nm}" > /dev/null
cert_arn="${__RESULT}"

if [[ -n "${cert_arn}" ]]
then 
   echo 'WARN: found certificate in IAM, deleting ...'
  
   # The certificate may still be locked by the deleted HTTPS listener, retry to delete it error.
   # shellcheck disable=SC2015
   delete_server_certificate "${crt_entity_nm}" > /dev/null 2>&1 && echo 'Server certificate deleted.' ||
   {
      __wait 30
      delete_server_certificate "${crt_entity_nm}" > /dev/null 2>&1 && echo 'Server certificate deleted.' ||
      {
         __wait 30
         delete_server_certificate "${crt_entity_nm}" > /dev/null 2>&1 && echo 'Server certificate deleted.' ||
         {
            echo 'Error: deleting server certificate.'
            exit 1
         }
      }
   }
fi

# Wait until the certificate is removed from IAM.
get_server_certificate_arn "${crt_entity_nm}" > /dev/null
cert_arn="${__RESULT}"

# shellcheck disable=SC2015
test -z "${cert_arn}" || 
{  
   __wait 30
   get_server_certificate_arn "${crt_entity_nm}" > /dev/null
   cert_arn="${__RESULT}"
   
   test -z "${cert_arn}" ||
   {
      __wait 30
      get_server_certificate_arn "${crt_entity_nm}" > /dev/null
      cert_arn="${__RESULT}"
      
      test -z "${cert_arn}" || 
      {
         # Raise an error if the cert is stil visible.
         echo 'ERROR: certificate not deleted from IAM.'
         exit 1     
      }        
   }
}
   
cd "${TMP_DIR}"/"${lbal_dir}"

if [[ 'development' == "${ENV}" ]]
then

   #
   # Development: 
   # generate and upload a self-signed certificate to IAM.
   #
   # key.pem
   # cert.pem
   #
 
   echo 'Creating self-signed SSL Certificate ...'

   # Generate RSA encrypted private key, protected with a passphrase.
   cp "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_rsa.sh gen_rsa.sh

   echo 'gen_rsa.sh ready.'

   # Remove the password protection from the key file.
   cp "${TEMPLATE_DIR}"/common/ssl/selfsigned/remove_passphase.sh remove_passphase.sh   
      
   echo 'remove_passphase.sh ready.'

   # Create a self-signed Certificate.
   sed -e "s/SEDcountrySED/${DEV_LBAL_CRT_COUNTRY_NM}/g" \
       -e "s/SEDstate_or_provinceSED/${DEV_LBAL_CRT_PROVINCE_NM}/g" \
       -e "s/SEDcitySED/${DEV_LBAL_CRT_CITY_NM}/g" \
       -e "s/SEDorganizationSED/${DEV_LBAL_CRT_ORGANIZATION_NM}/g" \
       -e "s/SEDunit_nameSED/${DEV_LBAL_CRT_UNIT_NM}/g" \
       -e "s/SEDcommon_nameSED/${LBAL_INST_DNS_DOMAIN_NM}/g" \
       -e "s/SEDemail_addressSED/${LBAL_EMAIL_ADD}/g" \
          "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_certificate_template.sh > gen_certificate.sh
             
   echo 'gen_certificate.sh ready.'

   cp "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_selfsigned_certificate.sh gen_selfsigned_certificate.sh    
      
   echo 'gen_selfsigned_certificate.sh ready.'

   chmod +x gen_selfsigned_certificate.sh
   ./gen_selfsigned_certificate.sh 
       
   echo 'Self-signed SSL certificate created.'
   echo 'Uploading SSL certificate to IAM ...'
   
   upload_server_certificate_entity "${crt_entity_nm}" cert.pem key.pem \
       "${TMP_DIR}"/"${lbal_dir}" > /dev/null  
else

   #
   # Production: 
   # install acme.sh client in the Admin instance and request a certificate signed by Let's Encrypt,
   # download the certificate from Admin and upload it to IAM.
   #
     
   # SSH Access to Admin instance.
   granted_admin_ssh="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0')"

   if [[ -n "${granted_admin_ssh}" ]]
   then
      echo 'WARN: SSH access to the Admin box already granted.'
   else
      allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   
      echo 'Granted SSH access to the Admin box.'
   fi

   echo 'Uploading the scripts to the Admin box ...'

   remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
   cert_dir="${remote_dir}"/certificates
   key_pair_file="$(get_keypair_file_path "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}")"
   wait_ssh_started "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

   ssh_run_remote_command "rm -rf ${remote_dir} && mkdir -p ${cert_dir}" \
       "${key_pair_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"
       
   sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
       -e "s/SEDadmin_inst_emailSED/${ADMIN_INST_EMAIL}/g" \
       -e "s/SEDcert_home_dirSED/$(escape ${cert_dir})/g" \
       -e "s/SEDdomain_nmSED/${LBAL_INST_DNS_DOMAIN_NM}/g" \
       -e "s/SEDcrt_file_nmSED/${crt_file_nm}/g" \
       -e "s/SEDkey_file_nmSED/${key_file_nm}/g" \
       -e "s/SEDfull_chain_file_nmSED/${full_chain_file_nm}/g" \
          "${TEMPLATE_DIR}"/common/ssl/ca/request_ca_certificate_with_dns_challenge_template.sh > request_ca_certificate_with_dns_challenge.sh
          
   echo 'request_ca_certificate_with_dns_challenge.sh ready.'              

   scp_upload_files "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${lbal_dir}"/request_ca_certificate_with_dns_challenge.sh 
       
   echo 'Scripts uploaded.'
     
   ## 
   ## Remote commands that have to be executed as priviledged user are run with sudo.
   ## By AWS default, sudo has not password.
   ## 

   echo 'Requesting SSL certificate ...'
    
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/request_ca_certificate_with_dns_challenge.sh" \
       "${key_pair_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"

   set +e             
   ssh_run_remote_command_as_root "${remote_dir}/request_ca_certificate_with_dns_challenge.sh" \
       "${key_pair_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"       
   exit_code=$?
   set -e
     
   # shellcheck disable=SC2181
   if [ 0 -eq "${exit_code}" ]
   then 
      echo 'SSL certificate successfully retrieved.'
      
      download_dir="${TMP_DIR}"/"${lbal_dir}"/"$(date +"%d-%m-%Y")"

      if [[ ! -d "${download_dir}" ]]
      then
         mkdir -p "${download_dir}"
      fi
     
      # Download the certificates.                   
      scp_download_files "${key_pair_file}" \
          "${admin_eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${ADMIN_INST_USER_NM}" \
          "${cert_dir}" \
          "${download_dir}" \
          "${crt_file_nm}" "${key_file_nm}" "${full_chain_file_nm}" 
 
      echo 'Certificates downloaded.'
      echo "Check the directory: ${download_dir}"   
      echo 'Uploading SSL certificate to IAM ...'
         
      upload_server_certificate_entity "${crt_entity_nm}" "${crt_file_nm}" "${key_file_nm}" \
          "${download_dir}" "${full_chain_file_nm}" > /dev/null
          
      ssh_run_remote_command "rm -rf ${remote_dir:?}" \
          "${key_pair_file}" \
          "${admin_eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${ADMIN_INST_USER_NM}"   
                   
      echo 'Cleared remote directory.'
   else
      echo 'ERROR: configuring load balancer''s SSL.' 
      exit 1
   fi       
fi

if [[ 'production' == "${ENV}" ]]
then
   ## 
   ## SSH Access.
   ##

   granted_admin_ssh="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0')"

   if [[ -n "${granted_admin_ssh}" ]]
   then
      revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null
   
      echo 'Revoked SSH access to the Admin box.' 
   fi
fi
    
# Wait until the certificate is visible in IAM.
get_server_certificate_arn "${crt_entity_nm}" > /dev/null
cert_arn="${__RESULT}"

# shellcheck disable=SC2015
test -n "${cert_arn}" && echo 'Certificate uploaded.' || 
{  
   __wait 30
   get_server_certificate_arn "${crt_entity_nm}" > /dev/null
   cert_arn="${__RESULT}"
   test -n "${cert_arn}" &&  echo 'Certificate uploaded.' ||
   {
      __wait 30
      get_server_certificate_arn "${crt_entity_nm}" > /dev/null
      cert_arn="${__RESULT}"
      test -n "${cert_arn}" &&  echo 'Certificate uploaded.' || 
      {
         # Throw an error if after 90 secs the cert is stil not visible.
         echo 'ERROR: certificate not uploaded to IAM.'
         exit 1     
      }       
   }
}

get_server_certificate_arn "${crt_entity_nm}" > /dev/null
cert_arn="${__RESULT}"

# Create listener action is idempotent, we can skip checking if the listener exists.
# Even if the IAM command list-server-certificates has returned the certificate ARN, the certificate 
# may still not be available and add listener command may fail if called too early. 
# shellcheck disable=SC2015
add_https_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" "${cert_arn}" && echo 'HTTPS listener added.' ||
{
   __wait 30
   add_https_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" "${cert_arn}" && echo 'HTTPS listener added.' ||
   {
      __wait 30
      add_https_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" "${cert_arn}" && echo 'HTTPS listener added.' ||
      {
         echo 'ERROR: adding HTTPS listener.'
         exit 1
      }
   }
}

# Check HTTPS access from the Internet to the load balancer.
granted_https="$(check_access_from_cidr_is_granted  "${lbal_sgp_id}" "${LBAL_INST_HTTPS_PORT}" 'tcp' '0.0.0.0/0')"

if [[ -z "${granted_https}" ]]
then
   allow_access_from_cidr "${lbal_sgp_id}" "${LBAL_INST_HTTPS_PORT}" 'tcp' '0.0.0.0/0' > /dev/null
   
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



