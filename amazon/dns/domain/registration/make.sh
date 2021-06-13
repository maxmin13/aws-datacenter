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

echo '*******************'
echo 'DNS domain register'
echo '*******************'
echo

registered="$(check_domain_is_registered_with_the_account "${MAXMIN_TLD}")"

if [[ -n "${registered}" ]]
then
   echo "The ${MAXMIN_TLD} domain is registered with the account."
else
   echo "* WARN: the '${MAXMIN_TLD}' domain is not registered with the account."
   
   status="$(get_request_status 'REGISTER_DOMAIN')" 

   if [[ 'IN_PROGRESS' == "${status}" ]]
   then
      echo '* WARN: a registration request has already been submitted.'
   else
      availability="$(check_domain_availability "${MAXMIN_TLD}")"

      if [[ "${availability}" != 'AVAILABLE' ]]
      then
         echo "* WARN: the ${MAXMIN_TLD} domain is not available for registration."
      else
         echo "The ${MAXMIN_TLD} domain is available, registering."
         
         register_domain "${TEMPLATE_DIR}"/dns/register-domain.json
         
         echo 'Request sent to the AWS registrar.' 
      fi     
   fi
fi

echo
