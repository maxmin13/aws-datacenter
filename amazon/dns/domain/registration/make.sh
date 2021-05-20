#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Registers the maxmin.it domain with AWS 
# registrar. 
###############################################


echo '*******************'
echo 'DNS domain register'
echo '*******************'
echo

error=0

availability="$(check_domain_availability "${MAXMIN_TLD}")"

if [[ "${availability}" != 'AVAILABLE' ]]
then
   echo "* WARN: the '${MAXMIN_TLD}' domain is not available"
   error=1
fi

if [[ -f "${DOWNLOAD_DIR}/domain_registration.txt" ]]
then
   echo "* WARN: a registration request has been already submitted"
   operation_id="$(cat "${DOWNLOAD_DIR}"/domain_registration.txt)"  
   error=1
fi

echo

if [[ "${error}" -eq 0 ]]
then
   echo "The '${MAXMIN_TLD}' domain is available"
   echo 'Registering the domain with the AWS registrar ...'

   operation_id="$(register_domain "${TEMPLATE_DIR}/dns/register-domain.json")"

   # Save the registration id.
   echo "Operation ID: ${operation_id}"
   echo "${operation_id}" >> "${DOWNLOAD_DIR}/domain_registration.txt" 
 
   echo 'Request sent to the AWS registrar.' 
fi

if [[ -n "${operation_id}" ]]
then
   date="$(get_request_date "${operation_id}")" 
   status="$(get_request_status "${operation_id}")" 
   
   echo "Date of submission: ${date}"  
   echo "Date of status: ${status}"
fi

echo
