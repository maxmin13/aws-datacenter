#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

AWS_USER_NM='aws-user'
AWS_ROUTE53_POLICY_NM='Route53policy'

echo '*********'
echo 'AWS Users'
echo '*********'
echo

check_user_exists "${AWS_USER_NM}"
user_exists="${__RESULT}"
__RESULT=''
get_user_arn "${AWS_USER_NM}"
user_arn="${__RESULT}"
__RESULT=''

if [[ 'false' == "${user_exists}" ]]
then
   echo '* WARN: IAM user not found.'
else
   echo "* IAM user ARN: ${user_arn}"
fi

check_managed_policy_exists "${AWS_ROUTE53_POLICY_NM}"
policy_exists="${__RESULT}"
__RESULT=''
get_managed_policy_arn "${AWS_ROUTE53_POLICY_NM}"
policy_arn="${__RESULT}"
__RESULT=''

if [[ 'false' == "${policy_exists}" ]]
then
   echo '* WARN: Policy not found.'
else
   echo "* Policy ARN: ${policy_arn}"
fi

echo

if [[ 'true' == "${user_exists}" ]]
then
   delete_user "${AWS_USER_NM}"
   
   echo 'AWS user deleted.'
fi

if [[ 'true' == "${policy_exists}" ]]
then
   delete_managed_policy "${AWS_ROUTE53_POLICY_NM}"
   
   echo 'Managed policy deleted.'
fi



echo 
                  

