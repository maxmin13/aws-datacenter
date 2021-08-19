#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace


###############################################
# Create an IAM role that has permissions to 
# create and delete DNS records in Route 53.
# The role is entrusted to EC2 instances. 
###############################################

AWS_ROUTE53_POLICY_NM='Route53policy'
AWS_ROUTE53_ROLE_NM='Route53role'

echo '***************'
echo 'AWS Permissions'
echo '***************'
echo

##
## Role
##

check_role_exists "${AWS_ROUTE53_ROLE_NM}"
role_exists="${__RESULT}"

if [[ 'false' == "${role_exists}" ]]
then
   # Create the trust relationship policy document that grants the EC2 instances the
   # permission to assume the role.
   build_assume_role_policy_document_for_ec2_entities 
   trust_policy_document="${__RESULT}"

   create_role "${AWS_ROUTE53_ROLE_NM}" 'Access to Route 53 role' "${trust_policy_document}"
   
   echo 'AWS Route 53 role created.'
else
   echo 'WARN: AWS Route 53 role already created.'
fi

##
## Permissions policy.
##

check_permission_policy_exists "${AWS_ROUTE53_POLICY_NM}" > /dev/null 
policy_exists="${__RESULT}"

if [[ 'false' == "${policy_exists}" ]]
then
   # Create the IAM policy.
   build_route53_permission_policy_document
   permission_policy_document="${__RESULT}"

   create_permission_policy "${AWS_ROUTE53_POLICY_NM}" 'Access to Route 53 permission policy' \
       "${permission_policy_document}"
       
   echo 'Route 53 permission policy created.'
else
   echo 'WARN: Route 53 permission policy already created.'
fi

check_role_has_permission_policy_attached "${AWS_ROUTE53_ROLE_NM}" "${AWS_ROUTE53_POLICY_NM}"
policy_attached="${__RESULT}"

if [[ 'false' == "${policy_attached}" ]]
then
   attach_permission_policy_to_role "${AWS_ROUTE53_ROLE_NM}" "${AWS_ROUTE53_POLICY_NM}"
   
   echo 'Route 53 permission policy attached to role.'
else
   echo 'WARN: Route 53 prmission policy already attached to role.'
fi

echo
echo 'AWS permissions configured.'
echo
