#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####################################################################################
# Runs acme.sh script to obtain a certificate for the www.maxmin.it domain:
#
# 1) the script requests Let's Encrypt a certificate for the load balancer domain, 
# 2) the certification authority issues the challenge DNS-01 to add a txt record 
#    _acme-challenge.www.maxmin.it in the DNS,
# 3) acme.sh inserts the record in Route53 using the temporary credentials obtained 
#    from the role associated to the EC2 instance,
# 3) Let's Encrypt CA verifies the record in the DNS and issues the certificate,
# 4) acme.sh deletes the record from Route53. 
# 5) The certificates are copied in the script/certificates directory and downloaded
#    by the calling script'
#
# No, you don't need to renew the certs manually. All the certs will be renewed 
# automatically every 60 days.
####################################################################################

function __wait()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local seconds="${1}"
   local count=0
   
   while [[ "${count}" -lt "${seconds}" ]]; do
      printf '.'
      sleep 1
      count=$((count+1))
   done
   
   printf '\n'

   return 0
}

lbal_log_file='/var/log/lbal_request_ssl_certificate.log'
ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
ADMIN_INST_EMAIL='SEDadmin_inst_emailSED'
CERT_HOME_DIR='SEDcert_home_dirSED'
DOMAIN_NM='SEDdomain_nmSED'
CRT_FILE_NM='SEDcrt_file_nmSED'
KEY_FILE_NM='SEDkey_file_nmSED'
FULL_CHAIN_FILE_NM='SEDfull_chain_file_nmSED'

############### TODO error retrieving current directory: getcwd: cannot access parent directories: No such file or directory
############### 
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
############### 
############### 

# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

# If the domain name is fully qualified, remove the trailing dot.
sub_domain="$(echo "${DOMAIN_NM}" | cut -d'.' -f 1)"
domain="$(echo "${DOMAIN_NM}" | cut -d'.' -f 2)"
suffix="$(echo "${DOMAIN_NM}" | cut -d'.' -f 3)"
cert_domain="${sub_domain}"."${domain}"."${suffix}"

echo "Certificate domain ${cert_domain}."

cd "${script_dir}" || exit 1

##
## acme.sh client
##

# When the entries finished propagating we can install acme.sh and issue a certificate using the acme-dns method.
# All settings will be saved and the certificate will be renewed automatically.

# Since we are using Let's Encrypt staging environment, delete the previous acme.sh installation to force
# the dns challenge to be run again.
# If requesting a real certificate do not delete the previous installation.
acme_sh_home_dir='/root/.acme.sh'
rm -rf "${acme_sh_home_dir:?}"

echo 'Installing acme.sh client ...'

{
   curl https://get.acme.sh | sh 
}  >> "${lbal_log_file}" 2>&1

"${acme_sh_home_dir}"/acme.sh -f --set-default-ca --server letsencrypt >> "${lbal_log_file}" 2>&1 

##
## SSL certifcates 
## 

echo 'Requesting SSL certificate ...'
 
## TODO: Remove '--staging' to issue a valid certificate. Use '--debug 2' to debug the call.
## It may be that IAM is slow to give the permission to call Route 53 (see: ssl/loadbalancer.make.sh), retry after a while.
"${acme_sh_home_dir}"/acme.sh -f --staging --issue --dns dns_aws -d "${cert_domain}" >> "${lbal_log_file}" 2>&1 && \
echo 'Certificate successfully requested.' ||
{
   echo 'Let''s wait a bit and try again (second time).' >> "${lbal_log_file}" 2>&1
   __wait 180  
   echo 'Let''s try now.' >> "${lbal_log_file}" 2>&1
   
   "${acme_sh_home_dir}"/acme.sh -f --staging --issue --dns dns_aws -d "${cert_domain}" >> "${lbal_log_file}" 2>&1 && \
   echo 'Certificate successfully requested.' ||
   {
      echo 'Let''s wait a bit and try again (third time).' >> "${lbal_log_file}" 2>&1      
      __wait 180  
      echo 'Let''s try now.' >> "${lbal_log_file}" 2>&1
   
      "${acme_sh_home_dir}"/acme.sh -f --staging --issue --dns dns_aws -d "${cert_domain}" >> "${lbal_log_file}" 2>&1 && \
      echo 'Certificate successfully requested.' ||
      {
         echo 'Let''s wait a bit and try again (fourth time).' >> "${lbal_log_file}" 2>&1        
         __wait 180  
         echo 'Let''s try now.' >> "${lbal_log_file}" 2>&1
   
         "${acme_sh_home_dir}"/acme.sh -f --staging --issue --dns dns_aws -d "${cert_domain}" >> "${lbal_log_file}" 2>&1 && \
         echo 'Certificate successfully requested.' ||
         {
            echo 'Let''s wait a bit and try again (fourth time).' >> "${lbal_log_file}" 2>&1           
            __wait 180  
            echo 'Let''s try now.' >> "${lbal_log_file}" 2>&1
   
            "${acme_sh_home_dir}"/acme.sh -f --staging --issue --dns dns_aws -d "${cert_domain}" >> "${lbal_log_file}" 2>&1 && \
            echo 'Certificate successfully requested.' ||
            {
               echo 'ERROR: requesting certificate.'
               exit 1     
            }   
         }
      }      
   }       
}

cp "${acme_sh_home_dir}"/"${cert_domain}"/${cert_domain}.cer "${CERT_HOME_DIR}"/"${CRT_FILE_NM}"
cp "${acme_sh_home_dir}"/"${cert_domain}"/${cert_domain}.key "${CERT_HOME_DIR}"/"${KEY_FILE_NM}"
cp "${acme_sh_home_dir}"/"${cert_domain}"/fullchain.cer "${CERT_HOME_DIR}"/"${FULL_CHAIN_FILE_NM}"
   
echo "Certificates copied in ${CERT_HOME_DIR}." >> "${lbal_log_file}" 2>&1 

# Remove the server certificate from the chain (the first), IAM wants only the intermidiates and the root.
cd "${CERT_HOME_DIR}"

csplit -s -z -f cert- "${FULL_CHAIN_FILE_NM}" '/-----BEGIN CERTIFICATE-----/' '{*}'
mv "${FULL_CHAIN_FILE_NM}" "${FULL_CHAIN_FILE_NM}"_backup

cert_files="$(ls cert*)"
array_files=($cert_files)

for file in "${array_files[@]}"
do
   if [[ 'cert-00' != "${file}" ]]
   then
      cat "${file}" >> "${FULL_CHAIN_FILE_NM}"
   fi
done

echo 'Removed server certificate from the chain.'

exit 0
