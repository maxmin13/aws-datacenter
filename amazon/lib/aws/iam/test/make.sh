#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
 
counter=0

##
## Functions used to handle test data.
##

function __helper_create_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local name="${1}"
   local description='Create/delete Route 53 records.'
   local policy_document=''
   local arn=''

   policy_document=$(cat <<-'EOF' 
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "route53:DeleteTrafficPolicy",
            "route53:CreateTrafficPolicy"
         ],
         "Resource":"*"
      }
   ]
}      
	EOF
   )       
                
   aws iam create-policy \
          --policy-name "${name}" \
          --description "${description}" \
          --policy-document "${policy_document}" \
          --query "Policy.Arn" \
          --output text    

   return 0
}

function __helper_clear_policies()
{
   local arn=''

   arn="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].Arn" --output text)"

   if [[ -n "${arn}" ]]
   then
      echo deleting $arn
      set +e
      aws iam delete-policy --policy-arn "${arn}"
      set -e
   fi
   
   return 0
}

echo 'Starting IAN tests ...'

trap "__helper_clear_policies" EXIT

#################################################
## TEST 1: __build_route53_policy_document
#################################################

#
# Create a document policy for Route 53.
#

document_policy=''
document_policy="$(__build_route53_policy_document)"

## Validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${document_policy}"
then
    
    # Get the Version element.
    version="$(echo "${document_policy}" | jq -r '.Version')"

    if [[ '2012-10-17' != "${version}" ]]
    then
       echo "ERROR: testing __build_route53_policy_document wrong Version element."
       counter=$((counter +1))
    fi
    
    # Get the Effect element.
    effect="$(echo "${document_policy}" | jq -r '.Statement[0].Effect')"
    
    if [[ 'Allow' != "${effect}" ]]
    then
       echo "ERROR: testing __build_route53_policy_document wrong Effect element."
       counter=$((counter +1))
    fi
    
    # Get the first Action element.
    action="$(echo "${document_policy}" | jq -r '.Statement[0].Action[0]')"
    
    if [[ 'route53:DeleteTrafficPolicy' != "${action}" ]]
    then
       echo "ERROR: testing __build_route53_policy_document wrong first Action element."
       counter=$((counter +1))
    fi
    
    # Get the second Action element.
    action="$(echo "${document_policy}" | jq -r '.Statement[0].Action[1]')"
    
    if [[ 'route53:CreateTrafficPolicy' != "${action}" ]]
    then
       echo "ERROR: testing __build_route53_policy_document wrong second Action element."
       counter=$((counter +1))
    fi
    
    # Get the Resource element.
    resource="$(echo "${document_policy}" | jq -r '.Statement[0].Resource')"
    
    if [[ '*' != "${resource}" ]]
    then
       echo "ERROR: testing __build_route53_policy_document wrong Resource element."
       counter=$((counter +1))
    fi       
else
    echo "ERROR: Failed to parse JSON __build_route53_policy_document request batch."
    counter=$((counter +1))
fi

echo '__build_route53_policy_document tests completed.'

###########################################
## TEST 2: create_route53_policy
###########################################

__helper_clear_policies

#
# Missing argument.
#

set +e
create_route53_policy > /dev/null
exit_code=$?
set -e

if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing create_route53_policy with missing argument.'
   counter=$((counter +1))
fi

#
# Create a policy successfully.
#

arn="$(create_route53_policy 'Route-53-policy')"

if test -z "${arn}"
then
   echo 'ERROR: testing create_route53_policy.'
   counter=$((counter +1))
fi

name="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].PolicyName" --output text)"   
   
if [[ "${name}" != 'Route-53-policy' ]]
then
   echo 'ERROR: testing create_route53_policy, name not found.'
   counter=$((counter +1))
fi 

#
# Create a policy twice.
#

# An empty string is expected.

arn="$(create_route53_policy 'Route-53-policy')"

if test -n "${arn}"
then
   echo 'ERROR: testing create_route53_policy twice.'
   counter=$((counter +1))
fi

echo 'create_route53_policy tests completed.'

# Clear the policies.
__helper_clear_policies

###########################################
## TEST 2: delete_route53_policy
###########################################

__helper_create_policy 'Route-53-policy'

#
# Missing argument.
#

set +e
delete_route53_policy > /dev/null
exit_code=$?
set -e

# An error is expected.
if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing delete_route53_policy with missing argument.'
   counter=$((counter +1))
fi

#
# Delete a policy successfully.
#

delete_route53_policy 'Route-53-policy'

arn="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].Arn" --output text)"

# Emptry string is expected.
if [[ -n "${arn}" ]]
then
   echo 'ERROR: testing delete_route53_policy.'
   counter=$((counter +1))
fi

echo 'delete_route53_policy tests completed.'
   
##############################################
# Count the errors.
##############################################

if [[ "${counter}" -gt 0 ]]
then
   echo "iam.sh script test completed with ${counter} errors."
else
   echo 'iam.sh script test successfully completed.'
fi

exit 0
