#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

######################################################################################### 
# Submits a registration request to the Amazon registrar for the maxmin.it domain (in 
# app_consts.sh file) if available, creates a Route 53 hosted zone that has the 
# same name as the  domain. 
# The cost of the domain is billed to the current account.
#########################################################################################

export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../../../aws-datacenter && pwd)"

source "${PROJECT_DIR}"/amazon/lib/const/app_consts.sh
source "${PROJECT_DIR}"/amazon/lib/const/project_dirs.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains/route53domains.sh

echo
echo '*******************'
echo 'DNS domain register'
echo '*******************'
echo

changeinfo_id_file="${TMP_DIR}"/.changeinfo_id
declare -r dns_dir='dns'

# Removing old files
rm -rf "${TMP_DIR:?}"/"${dns_dir}"
mkdir "${TMP_DIR}"/"${dns_dir}"

validate_dns_domain "${MAXMIN_TLD}"
valid="${__RESULT}"

if [[ 'false' == "${valid}" ]]
then
   echo "ERROR: the ${MAXMIN_TLD} domain is not a valid it DNS name."
   exit 1  
fi

check_domain_is_registered_with_the_account "${MAXMIN_TLD}"
registered="${__RESULT}"

if [[ 'false' == "${registered}" ]]
then
   check_domain_availability "${MAXMIN_TLD}"
   availability="${__RESULT}"
   
   if [[ "${availability}" != 'AVAILABLE' ]]
   then
      echo "ERROR: the ${MAXMIN_TLD} domain is not available for registration."
      exit 1
   else
      echo "The ${MAXMIN_TLD} domain is available, registering ..."

      sed -e "s/SEDdns_domainSED/${MAXMIN_TLD}/g" \
          -e "s/SEDemail_addressSED/${ADMIN_INST_EMAIL}/g" \
             "${TEMPLATE_DIR}"/common/dns/register_domain_request_it_template.json > "${TMP_DIR}"/"${dns_dir}"/register_domain.json    
         
      ##### TODO: REMOVE THE COMMENT TO SEND THE REQUEST 
      # register_domain "${TMP_DIR}"/"${dns_dir}"/register_domain.json #########
      operation_id="${__RESULT}"
         
      echo 'Request sent to the AWS registrar.'
      echo "Operation ID: ${operation_id}" 
      
      # Save the id in the TMP_DIR/.changeinfo_id file
      echo "${changeinfo_id}" >> "${changeinfo_id_file}"
   fi 

   echo 'Domain registered, run the script again to check on the state of the request.'
fi   
 
if [[ 'true' == "${exists}" ]]   
then
   echo "Domain ${MAXMIN_TLD} already registered."
   
   if [[ -f "${changeinfo_id_file}"  ]]
   then
      changeinf_id="$(cat "${changeinfo_id_file}")"
      get_record_request_status "${changeinf_id}"
      request_status="${__RESULT}"
      
      echo "Request status ${request_status}"
      
      if [[ 'INSYNC' != "${request_status}" ]]
      then
      #   echo 'Hosted zone will be ready when the status of the request is INSYNC.'
      else
      #   echo 'Hosted zone is ready.'
         
        # rm "${changeinfo_id_file}"
      fi
   fi
fi

echo

echo

rm -rf "${TMP_DIR:?}"/"${dns_dir}"
