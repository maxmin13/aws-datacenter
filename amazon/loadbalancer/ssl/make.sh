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

ACME_DNS_DOMAIN_NM=acme-dns."${MAXMIN_TLD}"
ACME_DNS_DATABASE_DIR='/var/lib/acme-dns/acme-dns.db'
ACME_DNS_CERT_DIR='/var/lib/acme-dns/cert'
ACME_DNS_CONFIG_DIR='/etc/acme-dns'
ACME_DNS_BINARY_DIR='/usr/local/bin'
LETS_ENCRYPT_INSTALL_DIR='/etc/letsencrypt'
LETS_ENCRYPT_MODE='letsencryptstaging'

if [[ 'production' == "${ENV}" ]]
then
   crt_nm='lbal-prod-certificate'
else
   crt_nm='lbal-dev-certificate'  
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
   revoke_access_from_cidr "${lbal_sgp_id}" "${LBAL_INST_HTTP_PORT}" 'tcp' '0.0.0.0/0'
   
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
test -z "${cert_arn}" && echo 'Certificate deleted.' || 
{  
   __wait 30
   cert_arn="$(get_server_certificate_arn "${crt_nm}")"
   test -z "${cert_arn}" &&  echo 'Certificate deleted.' ||
   {
      __wait 30
      cert_arn="$(get_server_certificate_arn "${crt_nm}")"
      test -z "${cert_arn}" &&  echo 'Certificate deleted.' || 
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
   # generate and upload a self-signed Server Certificate to IAM.
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
       -e "s/SEDcommon_nameSED/${DEV_LBAL_CRT_COMMON_NM}/g" \
       -e "s/SEDemail_addressSED/${DEV_LBAL_LBAL_EMAIL_ADD}/g" \
          "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_certificate_template.sh > gen_certificate.sh
             
   echo 'gen_certificate.sh ready.'

   cp "${TEMPLATE_DIR}"/common/ssl/selfsigned/gen_selfsigned_certificate.sh gen_selfsigned_certificate.sh    
      
   echo 'gen_selfsigned_certificate.sh ready.'

   chmod +x gen_selfsigned_certificate.sh
   ./gen_selfsigned_certificate.sh 
       
   echo 'Self-signed SSL certificate created.'
   echo 'Uploading SSL certificate to IAM ...'
   
   upload_server_certificate "${crt_nm}" cert.pem key.pem "${TMP_DIR}"/"${lbal_dir}"  
else

   #
   # Production: 
   # install acme-dns server in the Admin instance and run the DNS-01 challenge to request a 
   # certificate signed by Let's Encrypt. Upload the signed certificate to IAM.
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

   # acme-dns needs to open a privileged 53 port UDP.
   # UDP/53 might work for most situations; it basically depends on the size of the DNS request,
   # which will have to be TCP once it gets too large (Like for DNSSEC). But if you are only 
   # doing one domain at a time, it may work.
 
   granted_acme_dns_udp_port="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'udp' '0.0.0.0/0')"
   
   if [[ -n "${granted_acme_dns_udp_port}" ]]
   then
      echo 'WARN: acme-dns access to the Admin box''s 53 UDP port already granted.'
   else
      allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'udp' '0.0.0.0/0'
   
      echo 'Granted acme-dns access to the Admin box''s 53 UDP port.'
   fi   

   # acme-dns api needs HTTPS port
   granted_acme_dns_https_port="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_HTTPS_PORT}" 'tcp' '0.0.0.0/0')"
   
   if [[ -n "${granted_acme_dns_https_port}" ]]
   then
      echo 'WARN: acme-dns access to the Admin box''s HTTPS port already granted.'
   else
      allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_HTTPS_PORT}" 'tcp' '0.0.0.0/0'
   
      echo 'Granted acme-dns access to the Admin box''s HTTPS port.'
   fi
   
   #
   # Publish in Route 53 the DNS records that establish your acme-dns instance as the authoritative 
   # nameserver for acme-dns.maxmin.it, eg: 
   #
   # acme-dns.maxmin.it	A  34.244.4.71
   # acme-dns.maxmin.it	NS acme-dns.maxmin.it
   #
   
   check_hosted_zone_has_record 'A' 'acme-dns'."${MAXMIN_TLD}"
   route53_has_acme_dns_A_record="${__RESULT}"
   
   if [[ 'true' == "${route53_has_acme_dns_A_record}" ]]
   then
      # If the record is there, delete it because it may be stale.
      get_record_value 'A' 'acme-dns'."${MAXMIN_TLD}"
      target_eip="${__RESULT}"
      
      echo "WARN: found acme-dns A record (${target_eip}), deleting ..."
      
      delete_record 'A' 'acme-dns'."${MAXMIN_TLD}" "${admin_eip}"
      request_id="${__RESULT}"                            
      get_record_request_status "${request_id}" 
      status="${__RESULT}" 
   
      echo "acme-dns A record deleted (${status})."
   fi
   
   create_record 'A' 'acme-dns'."${MAXMIN_TLD}" "${admin_eip}"  
   request_id="${__RESULT}"       
                                              
   get_record_request_status "${request_id}" 
   status="${__RESULT}"
   
   echo "acme-dns A record created (${status})."     
   
   check_hosted_zone_has_record 'NS' 'acme-dns'."${MAXMIN_TLD}"
   route53_has_acme_dns_NS_record="${__RESULT}"
   
   if [[ 'true' == "${route53_has_acme_dns_NS_record}" ]]
   then
      get_record_value 'NS' 'acme-dns'."${MAXMIN_TLD}"
      target_domain_mn="${__RESULT}"
        
      echo "WARN: found acme-dns NS record (${target_domain_mn}), deleting ..."
            
      delete_record 'NS' 'acme-dns'."${MAXMIN_TLD}" "${target_domain_mn}" 
      request_id="${__RESULT}"        
                           
      get_record_request_status "${request_id}" 
      status="${__RESULT}"
   
      echo "acme-dns A record deleted (${status})."
   fi

   create_record 'NS' 'acme-dns'."${MAXMIN_TLD}" "${admin_eip}"
   request_id="${__RESULT}"    
                            
   get_record_request_status "${request_id}" 
   status="${__RESULT}" 
   
   echo "acme-dns NS record created (${status})."  
   
   echo 'Uploading the scripts to the Admin box ...'

   remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
   key_pair_file="$(get_keypair_file_path "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}")"
   wait_ssh_started "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

   ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
       "${key_pair_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"

   sed -e "s/SEDaws_cli_repository_urlSED/$(escape "${AWS_CLI_REPOSITORY_URL}")/g" \
       -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
          "${TEMPLATE_DIR}"/common/aws/client/install_aws_cli_template.sh > install_aws_cli.sh   
    
   echo 'install_aws_cli.sh ready.'   
       
   sed -e "s/SEDacme_dns_git_repository_urlSED/$(escape "${ACME_DNS_GIT_REPOSITORY_URL}")/g" \
       -e "s/SEDadmin_inst_user_nmSED/${ADMIN_INST_USER_NM}/g" \
       -e "s/SEDacme_dns_config_dirSED/$(escape ${ACME_DNS_CONFIG_DIR})/g" \
       -e "s/SEDacme_dns_binary_dirSED/$(escape ${ACME_DNS_BINARY_DIR})/g" \
          "${TEMPLATE_DIR}"/common/ssl/ca/install_acme_dns_server_template.sh > install_acme_dns_server.sh         
          
   echo 'install_acme_dns_server.sh ready.'       
               
  # sed -e "s/^listen = .*/listen = \":${ADMIN_ACME_DNS_PORT}\"/g" \
 #      -e "s/auth.example.org./${ACME_DNS_DOMAIN_NM}/g" \
 #      -e "s/198.51.100.1/${admin_eip}/g" \
  #     -e "s/^connection = .*/connection = \"$(escape ${ACME_DNS_DATABASE_DIR})\"/g" \
  #     -e "s/^tls = .*/tls = ${LETS_ENCRYPT_MODE}/g" \
  #     -e "s/^port = .*/port = ${ADMIN_ACME_DNS_HTTPS_PORT}/g" \
   #    -e "s/^acme_cache_dir = .*/acme_cache_dir = $(escape ${ACME_DNS_CERT_DIR})/g" \
   #       "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg > config.cfg     
   
   
   ####### TODO PASS VARIABLES
   ######## TODO
sed -e 's/^listen = .*/listen = ":53"/g' "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg \
    -e 's/auth.example.org./acme-dns.example.com/g' "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg \
    -e "s/198.51.100.1/${admin_eip}/g" "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg \
    -e 's/^connection = .*/connection = "\/var\/lib\/acme-dns\/acme-dns.db"/g' "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg \
    -e 's/^tls = .*/tls = "letsencryptstaging"/g' "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg \
    -e 's/^port = .*/port = "9445"/g' "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg \
    -e 's/^acme_cache_dir = .*/acme_cache_dir = "\/var\/lib\/acme-dns\/cert"/g' "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg > config.cfg       
   
   echo 'config.cfg ready.'               
  
   scp_upload_files "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${lbal_dir}"/install_acme_dns_server.sh \
       "${TMP_DIR}"/"${lbal_dir}"/install_aws_cli.sh \
       "${TEMPLATE_DIR}"/common/aws/client/aws_cli_public_key \
       "${TEMPLATE_DIR}"/common/ssl/ca/request_ca_certificate_with_dns_challenge.sh \
       "${TMP_DIR}"/"${lbal_dir}"/config.cfg \
       "${TEMPLATE_DIR}"/common/ssl/ca/acme-dns.service 
    
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
      echo 'SSL certificate successfully requested.' 
     
     #### DOWNLOAD CERTIFICATE 
     
     ## UPLOAD CERTIFICATE TO IAM
     
     
    #########  ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    #########      "${key_pair_file}" \
   #######       "${admin_eip}" \
    ################      "${SHARED_INST_SSH_PORT}" \
   ##############       "${ADMIN_INST_USER_NM}"   
                   
      echo 'Cleared remote directory.'
   else
      echo 'ERROR: configuring load balancer''s SSL.' 
      exit 1
   fi       
fi

## 
## SSH Access.
##

####granted_admin_ssh="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0')"

#####if [[ -n "${granted_admin_ssh}" ]]
####then
####   revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   
####   echo 'Revoked SSH access to the Admin box.' 
####fi


# acme-dns needs to open a privileged port 53 udp
####   granted_acme_dns_port_udp="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'udp' '0.0.0.0/0')"

#####if [[ -n "${granted_acme_dns_port_udp}" ]]
####then
####   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'udp' '0.0.0.0/0'
   
####   echo 'Revoked acme-dns access to the Admin box.'
####fi

# acme-dns needs to open a privileged port 53 tcp
####   granted_acme_dns_port_udp="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'tcp' '0.0.0.0/0')"

#####if [[ -n "${granted_acme_dns_port_udp}" ]]
####then
####   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'tcp' '0.0.0.0/0'
   
####   echo 'Revoked acme-dns access to the Admin box.'
####fi

## STOP ACME-DNS
 
## REMOVE RECORDS FROM ROUTE 53
    
# Wait until the certificate is visible in IAM.
get_server_certificate_arn "${crt_nm}"
cert_arn="__RESULT"
# shellcheck disable=SC2015
test -n "${cert_arn}" && echo 'Certificate uploaded.' || 
{  
   __wait 30
   get_server_certificate_arn "${crt_nm}"
   cert_arn="__RESULT"
   test -n "${cert_arn}" &&  echo 'Certificate uploaded.' ||
   {
      __wait 30
      get_server_certificate_arn "${crt_nm}"
      cert_arn="__RESULT"
      test -n "${cert_arn}" &&  echo 'Certificate uploaded.' || 
      {
         # Throw an error if after 90 secs the cert is stil not visible.
         echo 'ERROR: certificate not uploaded to IAM.'
         exit 1     
      }       
   }
}

get_server_certificate_arn "${crt_nm}"
cert_arn="__RESULT"

# Create listener action is idempotent, we can skip checking if the listener exists.
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
granted_https="$(check_access_from_cidr_is_granted  "${lbal_sgp_id}" "${LBAL_INST_HTTPS_PORT}" 'tcp' '0.0.0.0/0')"

if [[ -z "${granted_https}" ]]
then
   allow_access_from_cidr "${lbal_sgp_id}" "${LBAL_INST_HTTPS_PORT}" 'tcp' '0.0.0.0/0'
   
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



