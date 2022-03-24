#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#########################################################################################
# Checks if the domain contained in the MAXMIN_TLD variable is registered with AWS,  
# if not, checks if it's available and submit a registration request. 
# The request is for an .it domain registration with no automatic renewal after a year 
# and with privacy protection enabled.
# The cost of the domain is billed to the current account.
#########################################################################################

declare -r dns_dir='dns'

echo
echo '*******************'
echo 'DNS domain register'
echo '*******************'
echo

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

if [[ 'true' == "${registered}" ]]
then
   echo 'The ${MAXMIN_TLD} domain is already registered with the account.'
else
   echo "* WARN: the ${MAXMIN_TLD} domain is not registered with the account."
   
   get_request_status 'REGISTER_DOMAIN'
   request_status="${__RESULT}"

   if [[ 'IN_PROGRESS' == "${request_status}" ]]
   then
      echo '* WARN: a registration request has already been submitted.'
   else
      echo 'The domain registration is not in progress, checking if the domain is available ...'

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
         
         register_domain "${TMP_DIR}"/"${dns_dir}"/register_domain.json
         operation_id="${__RESULT}"
         
         echo 'Request sent to the AWS registrar.'
         echo "Operation ID: ${operation_id}" 
      fi     
   fi
fi

rm -rf "${TMP_DIR:?}"/"${dns_dir}"
