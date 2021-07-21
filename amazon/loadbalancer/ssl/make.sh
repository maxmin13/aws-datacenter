#!/bin/bash

# shellcheck disable=SC2034

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

########################################################################
## The script configure SSL in the load balancer.
## It adds an HTTPS listener to the load balancer on port 443 that   
## forwards the requests to the webphp websites on port 8070 unencrypted  
## and remove the HTTP listener. 
## The script uploads an SSL certificate to IAM. In development the 
## certificate is self-signed, in production the certificate is signed 
## by Let's Encrypt certificate authority.
########################################################################

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
mkdir -p "${TMP_DIR}"/"${lbal_dir}"

##
## Security group.
##

# Check HTTP access from the Internet to the load balancer.
granted_lbal_http="$(check_access_from_cidr_is_granted  "${lbal_sgp_id}" "${LBAL_INST_HTTP_PORT}" '0.0.0.0/0')"

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
## SSL certificate
##

## The load balancer certificates are handled by AWS Identity and Access Management (IAM).

if [[ 'production' == "${ENV}" ]]
then
   crt_nm='lbal-prod-certificate'
   GIT_ACME_DNS_URL='https://github.com/joohoi/acme-dns' 
   ACME_DNS_DOMAIN_NM='acme-dns'."${MAXMIN_TLD}"
   LETS_ENCRYPT_INSTALL_DIR='/etc/letsencrypt'
else
   crt_nm='lbal-dev-certificate'
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
   # Create and upload a self-signed Server Certificate to IAM:
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
   sed -e "s/SEDcountrySED/${CRT_COUNTRY_NM}/g" \
       -e "s/SEDstate_or_provinceSED/${CRT_PROVINCE_NM}/g" \
       -e "s/SEDcitySED/${CRT_CITY_NM}/g" \
       -e "s/SEDorganizationSED/${CRT_ORGANIZATION_NM}/g" \
       -e "s/SEDunit_nameSED/${CRT_UNIT_NM}/g" \
       -e "s/SEDcommon_nameSED/${CRT_COMMON_NM}/g" \
       -e "s/SEDemail_addressSED/${LBAL_EMAIL_ADD}/g" \
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
   # Install an acme-dns server in the Admin instance to run the DNS-01 certbot challenge.
   #
     
   # SSH Access to Admin instance.
   granted_admin_ssh="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" '0.0.0.0/0')"

   if [[ -n "${granted_admin_ssh}" ]]
   then
      echo 'WARN: SSH access to the Admin box already granted.'
   else
      allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   
      echo 'Granted SSH access to the Admin box.'
   fi

   # acme-dns needs to open a privileged port 53 tcp
   granted_acme_dns_tcp_port="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" '0.0.0.0/0')"
   
   if [[ -n "${granted_acme_dns_tcp_port}" ]]
   then
      echo 'WARN: acme-dns access to the Admin box''s 53 tcp port already granted.'
   else
      allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'tcp' '0.0.0.0/0'
   
      echo 'Granted acme-dns access to the Admin box''s 53 tcp port.'
   fi
   
   # acme-dns needs to open a privileged port 53 udp
   granted_acme_dns_udp_port="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" '0.0.0.0/0')"
   
   if [[ -n "${granted_acme_dns_udp_port}" ]]
   then
      echo 'WARN: acme-dns access to the Admin box''s 53 udp port already granted.'
   else
      allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'udp' '0.0.0.0/0'
   
      echo 'Granted acme-dns access to the Admin box''s 53 udp port.'
   fi   

   # acme-dns api needs HTTPS port
   granted_acme_dns_https_port="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_HTTPS_PORT}" '0.0.0.0/0')"
   
   if [[ -n "${granted_acme_dns_https_port}" ]]
   then
      echo 'WARN: acme-dns access to the Admin box''s HTTPS port already granted.'
   else
      allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_HTTPS_PORT}" 'tcp' '0.0.0.0/0'
   
      echo 'Granted acme-dns access to the Admin box''s HTTPS port.'
   fi
   
   #
   # Publish in Route 53 the DNS records that establish your acme-dns instance as the authoritative 
   # nameserver for acme-dns.maxmin.it: 
   #
   # acme-dns.maxmin.it	A  34.244.4.71
   # acme-dns.maxmin.it	NS acme-dns.maxmin.it
   #
   
   route53_has_acme_dns_A_record="$(check_hosted_zone_has_record 'acme-dns' "${MAXMIN_TLD}" 'A')"
   
   if [[ 'true' == "${route53_has_acme_dns_A_record}" ]]
   then
      # If the record is there, delete id because the IP address may be old.
      echo 'WARN: found acme-dns A record, deleting ...'
      
      target_eip="$(get_record_value 'acme-dns' "${MAXMIN_TLD}" 'A')"
   
      request_id="$(delete_record \
          'acme-dns' \
          "${MAXMIN_TLD}" \
          "${target_eip}")"
                                      
      status="$(get_record_request_status "${request_id}")"  
   
      echo "acme-dns A record deleted (${status})"
   fi
   
   ### TODO fix this passing A record type
   request_id="$(create_record \
       'acme-dns' \
       "${MAXMIN_TLD}" \
       "${admin_eip}")" 
                                    
   status="$(get_record_request_status "${request_id}")"  
   
   echo "acme-dns A record created (${status})."     
   
   route53_has_acme_dns_NS_record="$(check_hosted_zone_has_record 'acme-dns' "${MAXMIN_TLD}" 'NS')"
   
   if [[ 'true' == "${route53_has_acme_dns_NS_record}" ]]
   then
      echo 'WARN: found acme-dns NS record, deleting ...'
      
      target_eip="$(get_record_value 'acme-dns' "${MAXMIN_TLD}" 'NS')"
   
      request_id="$(delete_record \
          'acme-dns' \
          "${MAXMIN_TLD}" \
          "${target_eip}")"
                                      
      status="$(get_record_request_status "${request_id}")"  
   
      echo "acme-dns A record deleted (${status})"
   fi
   
   ### TODO fix this passing NS record type
   request_id="$(create_record \
       'acme-dns' \
       "${MAXMIN_TLD}" \
       "${admin_eip}")" 
                                    
   status="$(get_record_request_status "${request_id}")"  
   
   echo "acme-dns NS record created (${status})."  
   
 
   
   
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
       
   sed -e "s/SEDadmin_instance_user_nmSED/${ADMIN_INST_USER_NM}/g" \
       -e "s/SEDacme_dns_urlSED/$(escape ${GIT_ACME_DNS_URL})/g" \
          "${TEMPLATE_DIR}"/common/ssl/ca/install_acme_dns_server_template.sh > install_acme_dns_server.sh   
          
   echo 'install_acme_dns_server.sh ready.' 
           
   sed -e "s/^listen = .*/listen = \":${ADMIN_ACME_DNS_PORT}\"/g" \
       -e "s/auth.example.org/${ACME_DNS_DOMAIN_NM}/g" \
       -e "s/198.51.100.1/${admin_eip}/g" \
       -e "s/^connection = .*/connection = \"$(escape '/var/lib/acme-dns/acme-dns.db')\"/g" \
       -e 's/^tls = .*/tls = "letsencrypt"/g' \
       -e "s/^port = .*/port = \"${ADMIN_ACME_DNS_HTTPS_PORT}\"/g" \
       -e "s/^acme_cache_dir = .*/acme_cache_dir = \"$(escape '/var/lib/acme-dns/cert')\"/g" \
       -e "s/admin.example.org/${LBAL_EMAIL_ADD/@/\.}/g" \
          "${TEMPLATE_DIR}"/common/ssl/ca/config_template.cfg > config.cfg         
   
   echo 'config.cfg ready.'               
  
   scp_upload_files "${key_pair_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${lbal_dir}"/install_acme_dns_server.sh \
       "${TMP_DIR}"/"${lbal_dir}"/config.cfg \
       "${TEMPLATE_DIR}"/common/ssl/ca/acme-dns.service \
       "${TEMPLATE_DIR}"/loadbalancer/ssl/ca/install_loadbalancer_ssl.sh 
    
   echo 'Scripts uploaded.'
     
   ## 
   ## Remote commands that have to be executed as priviledged user are run with sudo.
   ## By AWS default, sudo has not password.
   ## 

   echo 'Installing SSL in the loadbalancer box ...'
    
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_loadbalancer_ssl.sh" \
       "${key_pair_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"

   set +e   
          
   ssh_run_remote_command_as_root "${remote_dir}/install_loadbalancer_ssl.sh" \
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
      echo 'SSL successfully configured in the load balancer box.' 
     
    #########  ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    #########      "${key_pair_file}" \
   #######       "${admin_eip}" \
    ################      "${SHARED_INST_SSH_PORT}" \
   ##############       "${ADMIN_INST_USER_NM}"   
                   
      echo 'Cleared remote directory.'
   else
      echo 'ERROR: configuring SSL in the load balancer box.' 
      exit 1
   fi       
fi

## 
## SSH Access.
##

####granted_admin_ssh="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" '0.0.0.0/0')"

#####if [[ -n "${granted_admin_ssh}" ]]
####then
####   revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   
####   echo 'Revoked SSH access to the Admin box.' 
####fi

# acme-dns needs to open a privileged port 53 tcp
####   granted_acme_dns_port_tcp="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" '0.0.0.0/0')"

#####if [[ -n "${granted_acme_dns_port_tcp}" ]]
####then
####   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'tcp' '0.0.0.0/0'
   
####   echo 'Revoked acme-dns access to the Admin box.'
####fi

# acme-dns needs to open a privileged port 53 udp
####   granted_acme_dns_port_udp="$(check_access_from_cidr_is_granted  "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" '0.0.0.0/0')"

#####if [[ -n "${granted_acme_dns_port_udp}" ]]
####then
####   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_ACME_DNS_PORT}" 'udp' '0.0.0.0/0'
   
####   echo 'Revoked acme-dns access to the Admin box.'
####fi
    
# Wait until the certificate is visible in IAM.
cert_arn="$(get_server_certificate_arn "${crt_nm}")"
# shellcheck disable=SC2015
test -n "${cert_arn}" && echo 'Certificate uploaded.' || 
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

cert_arn="$(get_server_certificate_arn "${crt_nm}")"

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
granted_https="$(check_access_from_cidr_is_granted  "${lbal_sgp_id}" "${LBAL_INST_HTTPS_PORT}" '0.0.0.0/0')"

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



