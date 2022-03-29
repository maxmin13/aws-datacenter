#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace


#################################################################################
# Create an IAM role for Bosh director.
#################################################################################

echo
echo '***************'
echo 'AWS Permissions'
echo '***************'
echo

##
## Bosh director role.
##

check_role_exists "${AWS_BOSH_DIRECTOR_ROLE_NM}"
director_role_exists="${__RESULT}"

if [[ 'false' == "${director_role_exists}" ]]
then
   create_role "${AWS_BOSH_DIRECTOR_ROLE_NM}" 'Bosh director role' "${trust_policy_document}" > /dev/null
   
   echo 'AWS Bosh director role created.'
else
   echo 'WARN: AWS Bosh director role already created.'
fi

check_role_has_permission_policy_attached "${AWS_BOSH_DIRECTOR_ROLE_NM}" "${AWS_BOSH_DIRECTOR_POLICY_NM}"
policy_attached="${__RESULT}"

if [[ 'false' == "${policy_attached}" ]]
then
   attach_permission_policy_to_role "${AWS_BOSH_DIRECTOR_ROLE_NM}" "${AWS_BOSH_DIRECTOR_POLICY_NM}"
   
   echo 'Bosh director permission policy attached to role.'
else
   echo 'WARN: Bosh director permission policy already attached to role.'
fi

echo
echo 'AWS permissions configured.'

