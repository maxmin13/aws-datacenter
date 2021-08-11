#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace


###############################################
# Create an IAM user that has permissions to 
# assume roles and to create and delete DNS 
# records in Route 53. 
###############################################

AWS_USER_NM='aws-user'
AWS_ROUTE53_POLICY_NM='Route53policy'

echo '*********'
echo 'AWS Users'
echo '*********'
echo

check_user_exists "${AWS_USER_NM}"
user_exists="${__RESULT}"
__RESULT=''
user_arn=''

if [[ 'false' == "${user_exists}" ]]
then
   # Create an IAM user that has permissions to assume roles and to manipulate DNS records.
   create_user "${AWS_USER_NM}"
   user_arn="${__RESULT}"
   
   echo 'AWS user created.'
else
   echo 'WARN: AWS user already created.'
fi

check_managed_policy_exists "${AWS_ROUTE53_POLICY_NM}"
policy_exists="${__RESULT}"
__RESULT=''

if [[ 'false' == "${policy_exists}" ]]
then
   # Create the IAM policy.
   __build_route53_managed_policy_document
   policy_document="${__RESULT}"

   create_managed_policy "${AWS_ROUTE53_POLICY_NM}" 'Route 53 create and delete records policy.' \
       "${policy_document}"
       
   echo 'Managed policy created.'
else
   echo 'WARN: managed policy already created.'
fi

check_user_has_managed_policy "${AWS_USER_NM}" "${AWS_ROUTE53_POLICY_NM}"
policy_attached="${__RESULT}"

if [[ 'false' == "${policy_attached}" ]]
then
   attach_managed_policy_to_user "${AWS_USER_NM}" "${AWS_ROUTE53_POLICY_NM}"
   
   echo 'Managed policy attached to the user.'
else
   echo 'WARN: managed policy already attached.'
fi

# Create the JSON file that defines the trust relationship of the IAM role.

echo
echo 'AWS users created.'
echo
