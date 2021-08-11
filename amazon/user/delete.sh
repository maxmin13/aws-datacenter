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

get_user_arn "${AWS_USER_NM}"
user_arn="${__RESULT}"

if [[ -z "${user_arn}" ]]
then
   echo '* WARN: IAM user not found.'
else
   echo "* IAM user ARN: ${user_arn}"
fi

get_policy_arn "${AWS_ROUTE53_POLICY_NM}"
policy_arn="${__RESULT}"

if [[ -z "${policy_arn}" ]]
then
   echo '* WARN: Policy not found.'
else
   echo "* Policy ARN: ${policy_arn}"
fi

echo

if [[ -n "${user_arn}" ]]
then
   delete_user "${AWS_USER_NM}"
fi

if [[ -n "${policy_arn}" ]]
then
   delete_policy "${AWS_ROUTE53_POLICY_NM}"
fi



echo 
                  

