#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '***************'
echo 'AWS Permissions'
echo '***************'
echo

check_role_exists "${AWS_ROUTE53_ROLE_NM}"
r53_role_exists="${__RESULT}"

if [[ 'false' == "${r53_role_exists}" ]]
then
   echo '* WARN: Route 53 role not found.'
else
   get_role_arn "${AWS_ROUTE53_ROLE_NM}" > /dev/null
   r53_role_arn="${__RESULT}"

   echo "* Route 53 role ARN: ${r53_role_arn}"
fi

check_permission_policy_exists "${AWS_ROUTE53_POLICY_NM}" > /dev/null
r53_policy_exists="${__RESULT}"

if [[ 'false' == "${r53_policy_exists}" ]]
then
   echo '* WARN: Route 53 policy not found.'
else  
   get_permission_policy_arn "${AWS_ROUTE53_POLICY_NM}" > /dev/null
   r53_policy_arn="${__RESULT}"

   echo "* Route 53 policy ARN: ${r53_policy_arn}"
fi

check_role_exists "${AWS_BOSH_DIRECTOR_ROLE}"
director_role_exists="${__RESULT}"

if [[ 'false' == "${director_role_exists}" ]]
then
   echo '* WARN: Bosh director role not found.'
else
   get_role_arn "${AWS_BOSH_DIRECTOR_ROLE}" > /dev/null
   director_role_arn="${__RESULT}"

   echo "* Bosh director role ARN: ${director_role_arn}"
fi

echo

##
## Route 53 role.
##

if [[ 'true' == "${r53_role_exists}" ]]
then
   delete_role "${AWS_ROUTE53_ROLE_NM}" > /dev/null
   
   echo 'Route 53 role deleted.'
fi

##
## Route 53 permission policy.
##

if [[ 'true' == "${r53_policy_exists}" ]]
then
   delete_permission_policy "${AWS_ROUTE53_POLICY_NM}"
   
   echo 'Route53 permission policy deleted.'
   echo
fi
 
##
## Bosh director role.
##    

if [[ 'true' == "${director_role_exists}" ]]
then
   delete_role "${AWS_BOSH_DIRECTOR_ROLE}" > /dev/null
   
   echo 'Bosh director role deleted.'
   echo
fi     

         

