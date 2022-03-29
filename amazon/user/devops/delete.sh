#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo
echo '***************'
echo 'AWS Permissions'
echo '***************'
echo

check_role_exists "${AWS_BOSH_DIRECTOR_ROLE_NM}"
director_role_exists="${__RESULT}"

if [[ 'false' == "${director_role_exists}" ]]
then
   echo '* WARN: Bosh director role not found.'
else
   get_role_arn "${AWS_BOSH_DIRECTOR_ROLE_NM}" > /dev/null
   director_role_arn="${__RESULT}"

   echo "* Bosh director role ARN: ${director_role_arn}"
fi

echo
 
##
## Bosh director role.
##    

if [[ 'true' == "${director_role_exists}" ]]
then
   delete_role "${AWS_BOSH_DIRECTOR_ROLE_NM}" > /dev/null
   
   echo 'Bosh director role deleted.'
fi     

         

