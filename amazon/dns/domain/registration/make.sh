#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Checks if the maxmin.it domain is registered
# with AWS, if not, checks if it's available 
# and submit a registration request. 
###############################################

echo
echo '*******************'
echo 'DNS domain register'
echo '*******************'
echo

check_domain_is_registered_with_the_account "${MAXMIN_TLD}"
registered="${__RESULT}"

if [[ -n "${registered}" ]]
then
   echo "The ${MAXMIN_TLD} domain is already registered with the account."
else
   echo "* WARN: the ${MAXMIN_TLD} domain is not registered with the account."
   
   get_request_status 'REGISTER_DOMAIN'
   request_status="${_RESULT}"

   if [[ 'IN_PROGRESS' == "${request_status}" ]]
   then
      echo '* WARN: a registration request has already been submitted.'
   else
      check_domain_availability "${MAXMIN_TLD}"
      availability="${__RESULT}"

      if [[ "${availability}" != 'AVAILABLE' ]]
      then
         echo "* WARN: the ${MAXMIN_TLD} domain is not available for registration."
      else
         echo "The ${MAXMIN_TLD} domain is available, registering."
         
         register_domain "${TEMPLATE_DIR}"/dns/register-domain.json
         operation_id="${__RESULT}"
         
         echo 'Request sent to the AWS registrar,'
         echo "operation ID: ${operation_id}" 
      fi     
   fi
fi


