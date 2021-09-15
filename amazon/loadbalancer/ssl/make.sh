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

echo
echo '*****************'
echo 'SSL load balancer'
echo '*****************'
echo

get_loadbalancer_dns_name "${LBAL_INST_NM}"
lbal_dns="${__RESULT}"

if [[ -z "${lbal_dns}" ]]
then
   echo '* ERROR: Load balancer box not found.'
   exit 1
else
   echo "* Load balancer DNS name: ${lbal_dns}."
fi

get_security_group_id "${LBAL_INST_SEC_GRP_NM}"
lbal_sgp_id="${__RESULT}"

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
      get_instance_state "${ADMIN_INST_NM}"
      admin_instance_st="${__RESULT}"
   
      echo "* Admin box ID: ${admin_instance_id} (${admin_instance_st})."
   fi   
   
   get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
   admin_sgp_id="${__RESULT}"

   if [[ -z "${admin_sgp_id}" ]]
   then
      echo '* ERROR: Admin security group not found.'
      exit 1
   else
      echo "* Admin security group ID: ${admin_sgp_id}."
   fi 
   
   get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
   admin_eip="${__RESULT}"

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
## Internet access.
##

# Check HTTP access from the Internet to the load balancer.
set +e
revoke_access_from_cidr "${lbal_sgp_id}" "${LBAL_INST_HTTP_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e

echo 'Revoked HTTP internet access to the load balancer.'

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
   echo 'WARN: load balancer SSL certificate found in IAM, deleting ...'
  
   # The certificate may still be locked by the deleted HTTPS listener, retry to delete it error.
   # shellcheck disable=SC2015
   delete_server_certificate "${crt_entity_nm}" > /dev/null 2>&1 && echo 'Load balancer server certificate deleted from IAM.' ||
   {
      __wait 30
      delete_server_certificate "${crt_entity_nm}" > /dev/null 2>&1 && echo 'Load balancer server certificate deleted from IAM.' ||
      {
         __wait 30
         delete_server_certificate "${crt_entity_nm}" > /dev/null 2>&1 && echo 'Load balancer server certificate deleted from IAM.' ||
         {
            echo 'ERROR: deleting server certificate.'
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
         echo 'ERROR: load balancer server certificate still present in IAM.'
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
       
   echo 'Load balander self-signed SSL certificate created.'
   echo 'Uploading load balancer SSL certificate to IAM ...'
   
   upload_server_certificate_entity "${crt_entity_nm}" cert.pem key.pem \
       "${TMP_DIR}"/"${lbal_dir}" > /dev/null  
else

   #
   # Production: 
   # install acme.sh client in the Admin instance and request a certificate signed by Let's Encrypt,
   # download the certificate from Admin.
   #
   
   #
   # Instance profile.
   #
   
   ## Check the Admin instance profile has the Route 53 role associated.
   ## The role is needed to perform Let's Encrypt DNS challenge.
   check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${AWS_ROUTE53_ROLE_NM}" > /dev/null
   has_role_associated="${__RESULT}"

   if [[ 'false' == "${has_role_associated}" ]]
   then
      # IAM is a bit slow, it might be necessary to retry the certificate request a few times. 
      associate_role_to_instance_profile "${ADMIN_INST_PROFILE_NM}" "${AWS_ROUTE53_ROLE_NM}"
      
      echo 'Route 53 role associated to the instance profile.'
   else
      echo 'WARN: Route 53 role already associated to the instance profile.'
   fi   
   
   #   
   # SSH Access.
   #
   
   set +e
   allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Granted SSH access to the Admin box.'
   echo 'Uploading the scripts to the Admin box ...'

   remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
   cert_dir="${remote_dir}"/certificates
   private_key_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 
   wait_ssh_started "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

   ssh_run_remote_command "rm -rf ${remote_dir} && mkdir -p ${cert_dir}" \
       "${private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"
       
   sed -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
       -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
       -e "s/SEDadmin_inst_emailSED/${ADMIN_INST_EMAIL}/g" \
       -e "s/SEDcert_home_dirSED/$(escape ${cert_dir})/g" \
       -e "s/SEDdomain_nmSED/${LBAL_INST_DNS_DOMAIN_NM}/g" \
       -e "s/SEDcrt_file_nmSED/${crt_file_nm}/g" \
       -e "s/SEDkey_file_nmSED/${key_file_nm}/g" \
       -e "s/SEDfull_chain_file_nmSED/${full_chain_file_nm}/g" \
          "${TEMPLATE_DIR}"/common/ssl/ca/request_ca_certificate_with_dns_challenge_template.sh > request_ca_certificate_with_dns_challenge.sh
          
   echo 'request_ca_certificate_with_dns_challenge.sh ready.'              

   scp_upload_files "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${lbal_dir}"/request_ca_certificate_with_dns_challenge.sh 
       
   echo 'Scripts uploaded.'
     
   ## 
   ## Remote commands that have to be executed as priviledged user are run with sudo.
   ## By AWS default, sudo has not password.
   ## 

   echo 'Requesting load balancer SSL certificate ...'
    
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/request_ca_certificate_with_dns_challenge.sh" \
       "${private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"

   set +e             
   ssh_run_remote_command_as_root "${remote_dir}/request_ca_certificate_with_dns_challenge.sh" \
       "${private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"       
   exit_code=$?
   set -e
     
   # shellcheck disable=SC2181
   if [ 0 -eq "${exit_code}" ]
   then 
      echo 'Load balancer SSL certificate successfully retrieved.'
      
      download_dir="${TMP_DIR}"/"${lbal_dir}"/"$(date +"%d-%m-%Y")"

      if [[ ! -d "${download_dir}" ]]
      then
         mkdir -p "${download_dir}"
      fi
     
      # Download the certificates.                   
      scp_download_files "${private_key_file}" \
          "${admin_eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${ADMIN_INST_USER_NM}" \
          "${cert_dir}" \
          "${download_dir}" \
          "${crt_file_nm}" "${key_file_nm}" "${full_chain_file_nm}" 
 
      echo 'Load balancer certificates downloaded to local machine,'
      echo "check the directory: ${download_dir}"   
      echo 'Uploading load balancer SSL certificate to IAM ...'
         
      upload_server_certificate_entity "${crt_entity_nm}" "${crt_file_nm}" "${key_file_nm}" \
          "${download_dir}" "${full_chain_file_nm}" > /dev/null
          
      echo 'Load balancer SSL certificate uploaded to IAM.'
          
      ssh_run_remote_command "rm -rf ${remote_dir:?}" \
          "${private_key_file}" \
          "${admin_eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${ADMIN_INST_USER_NM}"   
   else
      echo 'ERROR: configuring load balancer''s SSL.' 
      exit 1
   fi 
    
   #
   # Instance profile.
   #

   check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${AWS_ROUTE53_ROLE_NM}" > /dev/null
   has_role_associated="${__RESULT}"

   if [[ 'true' == "${has_role_associated}" ]]
   then
      ####
      #### Sessions may still be actives, they should be terminated by adding AWSRevokeOlderSessions permission
      #### to the role.
      ####
      remove_role_from_instance_profile "${ADMIN_INST_PROFILE_NM}" "${AWS_ROUTE53_ROLE_NM}"
     
      echo 'Route 53 role removed from the instance profile.'
   else
      echo 'WARN: Route 53 role already removed from the instance profile.'
   fi

   ## 
   ## SSH Access.
   ##

   set +e
   revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Revoked SSH access to the Admin box.'          
fi
  
# Wait until the certificate is visible in IAM.
get_server_certificate_arn "${crt_entity_nm}" > /dev/null
cert_arn="${__RESULT}"

# shellcheck disable=SC2015
test -n "${cert_arn}" && echo 'Load balancer SSL certificate visible in IAM.' || 
{  
   __wait 30
   get_server_certificate_arn "${crt_entity_nm}" > /dev/null
   cert_arn="${__RESULT}"
   test -n "${cert_arn}" &&  echo 'Load balancer SSL certificate visible in IAM.' ||
   {
      __wait 30
      get_server_certificate_arn "${crt_entity_nm}" > /dev/null
      cert_arn="${__RESULT}"
      test -n "${cert_arn}" &&  echo 'Load balancer SSL certificate visible in IAM.' || 
      {
         # Throw an error if after 90 secs the cert is stil not visible.
         echo 'ERROR: certificate not visible in IAM.'
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
add_https_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" "${cert_arn}" > /dev/null && \
echo 'Load balancer HTTPS listener added.' ||
{
   __wait 30
   add_https_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" "${cert_arn}" > /dev/null && \
   echo 'Load balancer HTTPS listener added.' ||
   {
      __wait 30
      add_https_listener "${LBAL_INST_NM}" "${LBAL_INST_HTTPS_PORT}" "${WEBPHP_APACHE_WEBSITE_HTTP_PORT}" "${cert_arn}" > /dev/null && \
      echo 'Load balancer HTTPS listener added.' ||
      {
         echo 'ERROR: adding HTTPS listener to the load balancer.'
         exit 1
      }
   }
}

# Check HTTPS access from the Internet to the load balancer.
set +e
allow_access_from_cidr "${lbal_sgp_id}" "${LBAL_INST_HTTPS_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e

echo 'Granted HTTPS internet access to the load balancer.'

get_loadbalancer_dns_name "${LBAL_INST_NM}"
lbal_dns="${__RESULT}" 

# Clear local files
rm -rf "${TMP_DIR:?}"/"${lbal_dir}"

echo
echo "Load Balancer up and running at: ${lbal_dns}."


