#!/bin/bash

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

############################################################################
# The script creates a new hosted zone with the name of the maxmin.it domain 
# and assigns the nameservers of the newly created hosted zone to the 
# domain.
# This procedure must be followed when the domain is migrated from another
# account, or when the hosted zone has been deleted and must be recreated.
# This porcedure isn't necessary when registering a domain with the Amazon
# registrar because in this case Amazon creates the hosted zone under the
# hood.
###########################################################################

export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../../aws-datacenter && pwd)"

source "${PROJECT_DIR}"/amazon/lib/const/app_consts.sh
source "${PROJECT_DIR}"/amazon/lib/const/project_dirs.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53/route53.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains/route53domains.sh

echo
echo '***********'
echo 'Hosted zone'
echo '***********'
echo

check_domain_is_registered_with_the_account "${MAXMIN_TLD}"
registered="${__RESULT}"

if [[ 'false' == "${registered}" ]]
then
   echo "ERROR: the ${MAXMIN_TLD} domain is not registered with the account."
   exit 1
fi

## 
## Hosted Zone maxmin.it
## 

hz_changeinfo_id_file="${TMP_DIR}"/.hzchangeinfo_id
ns_changeinfo_id_file="${TMP_DIR}"/.nschangeinfo_id
hosted_zone_nm="${MAXMIN_TLD}"

check_hosted_zone_exists "${hosted_zone_nm}" > /dev/null
exists="${__RESULT}"

if [[ 'false' == "${exists}" ]]
then
   echo "Creating ${hosted_zone_nm} hosted zone ..."

   create_hosted_zone "${hosted_zone_nm}" 'ref_hz_maxmin_it_15' 'maxmin.it public hosted zone'
   hz_changeinfo_id="${__RESULT}"
  
   echo "Hosted zone ${hosted_zone_nm} created."
   echo "Change info id ${hz_changeinfo_id}"
   
   # Save the id in the TMP_DIR/.hz_changeinfo_id_file file
   echo "${hz_changeinfo_id}" >> "${hz_changeinfo_id_file}"
   
   get_hosted_zone_name_servers "${MAXMIN_TLD}"
   name_servers="${__RESULT}"

   #echo "DEBUG: ${name_servers}"
   
   update_domain_registration_name_servers "${MAXMIN_TLD}" "${name_servers}"
   ns_changeinfo_id="${__RESULT}"
   
   echo "Doman registration name servers updated with the hosted zone name servers."
   echo "Change info id ${ns_changeinfo_id}"
   
   # Save the id in the TMP_DIR/.changeinfo_id file
   echo "${ns_changeinfo_id}" >> "${ns_changeinfo_id_file}"

   echo 'Hosted Zone created, run the script again to check on the state of the request.'
fi   
 
if [[ 'true' == "${exists}" ]]   
then
   echo "Hosted zone ${hosted_zone_nm} already created."
   
   if [[ -f "${hz_changeinfo_id_file}"  ]]
   then
      hz_changeinfo_id="$(cat "${hz_changeinfo_id_file}")"
      get_record_request_status "${hz_changeinfo_id}"
      hz_changeinfo_status="${__RESULT}"
      
      echo "Create hosted zone change info status ${hz_changeinfo_status}"
      
      if [[ 'INSYNC' != "${hz_changeinfo_status}" ]]
      then
         echo 'Hosted zone will be ready when the status of the request is INSYNC.'
      else
         echo 'Hosted zone is ready.'
         
         # rm "${hz_changeinfo_id_file}"
      fi
   fi
   
   if [[ -f "${ns_changeinfo_id_file}"  ]]
   then
      ns_changeinfo_id="$(cat "${ns_changeinfo_id_file}")"
      get_record_request_status "${ns_changeinfo_id}"
      ns_changeinfo_status="${__RESULT}"
      
      echo "Update domain name servers change info status ${ns_changeinfo_status}"
      
      # TODO remove the hidden file when the request is completed
   fi
fi

echo


