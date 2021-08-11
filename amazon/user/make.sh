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

# Create the IAM policy.
__build_route53_policy_document
policy_document="${__RESULT}"

create_policy "${AWS_ROUTE53_POLICY_NM}" 'Route 53 create and delete records policy.' 
    "${policy_document}"

# Create an IAM user that has permissions to assume roles and to manipulate DNS records.
create_user "${AWS_USER_NM}"
user_arn="${__RESULT}"
attach_policy_to_user "${AWS_USER_NM}" "${AWS_ROUTE53_POLICY_NM}"

# Create the JSON file that defines the trust relationship of the IAM role.

echo
echo 'AWS users created.'
echo
