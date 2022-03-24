#!/bin/bash

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#############################################################################
# Checks if the 'maxmin.it' hosted zone exists, if not, the script creates a 
# new hosted zone. Once created the hosted zone is never deleted, the 
# deletion from the account must be done manually, since it takes about 48 
# hours for the hosted zone to become operative.
###########################################################################

export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../../aws-datacenter && pwd)"

source "${PROJECT_DIR}"/amazon/lib/const/app_consts.sh
source "${PROJECT_DIR}"/amazon/lib/const/project_dirs.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53/route53.sh

echo
echo '***********'
echo 'Hosted zone'
echo '***********'
echo

## 
## Hosted Zone maxmin.it
## 

changeinfo_id_file="${TMP_DIR}"/.changeinfo_id
hosted_zone_nm="${MAXMIN_TLD}"

check_hosted_zone_exists "${hosted_zone_nm}" > /dev/null
exists="${__RESULT}"

if [[ 'false' == "${exists}" ]]
then
   echo "Creating ${hosted_zone_nm} hosted zone ..."

   create_hosted_zone "${hosted_zone_nm}" 'ref_hz_maxmin_it_11' 'maxmin.it public hosted zone'
   changeinfo_id="${__RESULT}"
  
   echo "Hosted zone ${hosted_zone_nm} creation in progress, it may take up to 48 hours to complete."
   echo "Change info id ${changeinfo_id}"
   
   # Save the id in the TMP_DIR/.changeinfo_id file
   echo "${changeinfo_id}" >> "${changeinfo_id_file}"

   echo 'Hosted Zone created, run the script again to check on the state of the request.'
fi   
 
if [[ 'true' == "${exists}" ]]   
then
   echo "Hosted zone ${hosted_zone_nm} already created."
   
   if [[ -f "${changeinfo_id_file}"  ]]
   then
      changeinf_id="$(cat "${changeinfo_id_file}")"
      get_record_request_status "${changeinf_id}"
      request_status="${__RESULT}"
      
      echo "Request status ${request_status}"
      
      if [[ 'INSYNC' != "${request_status}" ]]
      then
         echo 'Hosted zone will be ready when the status of the request is INSYNC.'
      else
         echo 'Hosted zone is ready.'
         
         rm "${changeinfo_id_file}"
      fi
   fi
fi

echo


