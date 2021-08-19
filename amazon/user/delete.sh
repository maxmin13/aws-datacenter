#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

AWS_ROUTE53_POLICY_NM='Route53policy'
AWS_ROUTE53_ROLE_NM='Route53role'

echo '***************'
echo 'AWS Permissions'
echo '***************'
echo

check_role_exists "${AWS_ROUTE53_ROLE_NM}" > /dev/null
role_exists="${__RESULT}"

if [[ 'false' == "${role_exists}" ]]
then
   echo '* WARN: role not found.'
else
   get_role_arn "${AWS_ROUTE53_ROLE_NM}" > /dev/null
   role_arn="${__RESULT}"

   echo "* Role ARN: ${role_arn}"
fi

check_permission_policy_exists "${AWS_ROUTE53_POLICY_NM}" > /dev/null
policy_exists="${__RESULT}"

if [[ 'false' == "${policy_exists}" ]]
then
   echo '* WARN: Policy not found.'
else  
   get_permission_policy_arn "${AWS_ROUTE53_POLICY_NM}" > /dev/null
   policy_arn="${__RESULT}"

   echo "* Policy ARN: ${policy_arn}"
fi

echo

#
# AWS role.
#

if [[ 'true' == "${role_exists}" ]]
then
   delete_role "${AWS_ROUTE53_ROLE_NM}"
   
   echo 'AWS role deleted.'
fi

#
# Permission policy.
#

if [[ 'true' == "${policy_exists}" ]]
then
   delete_permission_policy "${AWS_ROUTE53_POLICY_NM}"
   
   echo 'Permission policy deleted.'
   echo
fi
 
                  

