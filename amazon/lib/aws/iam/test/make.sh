#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace
 
counter=0
__RESULT=''

##
## Functions used to handle test data.
##

function __helper_create_managed_policy_document()
{
   local policy_document=''
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
   
   eval "__RESULT='${policy_document}'"
   
   return 0
}

function __helper_create_managed_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   declare -r policy_nm="${1}"
   declare -r policy_desc='Create/delete Route 53 records.'
   local policy_document=''
   local policy_arn=''

   __helper_create_managed_policy_document
   policy_document="${__RESULT}"      
                
   policy_arn="$(aws iam create-policy \
       --policy-name "${policy_nm}" --description "${policy_desc}" \
       --policy-document "${policy_document}" --query "Policy.Arn" --output text)"  

   eval "__RESULT='${policy_arn}'"
   
   return 0
}

function __helper_clear_resources()
{
   local policy_arn=''
   local user_id=''
   
   # Clear the global __RESULT variable.
   __RESULT=''
   
   policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].Arn" \
       --output text)"
   user_id="$(aws iam list-users --query "Users[? UserName=='tech1'].UserId" --output text)"       
  
   if [[ -n "${user_id}" ]]
   then
      if [[ -n "${policy_arn}" ]]
      then
         aws iam detach-user-policy --user-name 'tech1' --policy-arn "${policy_arn}"
         
         echo 'Policy detached from from user.'
      fi
      
      aws iam delete-user --user-name 'tech1'
      
      echo 'User deleted.'
   fi
   
   if [[ -n "${policy_arn}" ]]
   then
      aws iam delete-policy --policy-arn "${policy_arn}"
   
      echo 'Policy deleted'
   fi

   return 0   
}

##
##
##
echo 'Starting iam.sh script tests ...'
echo
##
##
##

trap "__helper_clear_resources > /dev/null 2>&1" EXIT

##############################################################
## TEST 3: check_user_has_managed_policy
##############################################################

__helper_clear_resources > /dev/null 2>&1 

# Create a user with a policy attached.
aws iam create-user --user-name 'tech1' > /dev/null 2>&1 
__helper_create_managed_policy 'Route-53-policy' > /dev/null 2>&1
policy_arn="${__RESULT}"
__RESULT=''
aws iam attach-user-policy --user-name 'tech1' --policy-arn "${policy_arn}" 

#
# Missing argument.
#

set +e
check_user_has_managed_policy 'tech1' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_user_has_managed_policy with missing arguments.'
   counter=$((counter +1))
fi

#
# Not existing user.
#

set +e
check_user_has_managed_policy 'tech33' 'Route-53-policy' > /dev/null 2>&1
exit_code=$?
set -e
policy_attached="${__RESULT}"
__RESULT=''

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing check_user_has_managed_policy with not existing user.'
   counter=$((counter +1))
fi

# false is expected.
if [[ 'false' != "${policy_attached}" ]]
then
   echo 'ERROR: testing check_user_has_managed_policy with not existing user.'
   counter=$((counter +1))
fi

#
# Not existing policy.
#

check_user_has_managed_policy 'tech1' 'xxxxx-53-policy' > /dev/null 2>&1
exit_code=$?
policy_attached="${__RESULT}"
__RESULT=''

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_user_has_managed_policy with not existing policy.'
   counter=$((counter +1))
fi

# false is expected.
if [[ 'false' != "${policy_attached}" ]]
then
   echo 'ERROR: testing check_user_has_managed_policy with not existing policy.'
   counter=$((counter +1))
fi

echo 'check_user_has_managed_policy tests completed.'

##############################################################
## TEST 3: check_managed_policy_exists
##############################################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing argument.
#

set +e
check_managed_policy_exists > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_managed_policy_exists with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing policy.
#

check_managed_policy_exists 'xxxxx-53-policy' > /dev/null 2>&1
policy_exists="${__RESULT}"
__RESULT=''

if [[ 'false' != "${policy_exists}" ]]
then
   echo 'ERROR: testing check_managed_policy_exists with not existing policy.'
   counter=$((counter +1))
fi

#
# Success.
#

__helper_create_managed_policy 'Route-53-policy' > /dev/null 2>&1
__RESULT=''

check_managed_policy_exists 'Route-53-policy' > /dev/null 2>&1
policy_exists="${__RESULT}"
__RESULT=''

if [[ 'true' != "${policy_exists}" ]]
then
   echo 'ERROR: testing check_managed_policy_exists with valid policy.'
   counter=$((counter +1))
fi

echo 'check_managed_policy_exists tests completed.'

###########################################
## TEST 3: get_managed_policy_arn
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing argument.
#

set +e
get_managed_policy_arn > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_managed_policy_arn with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing policy.
#

get_managed_policy_arn 'xxxxx-53-policy' > /dev/null 2>&1
policy_arn="${__RESULT}"
__RESULT=''

# Empty string expected
if [[ -n "${policy_arn}" ]]
then
   echo 'ERROR: testing get_managed_policy_arn with not existing policy.'
   counter=$((counter +1))
fi

#
# Success.
#

__helper_create_managed_policy 'Route-53-policy' > /dev/null 2>&1
__RESULT=''

get_managed_policy_arn 'Route-53-policy' > /dev/null 2>&1
policy_arn="${__RESULT}"
__RESULT=''

if [[ -z "${policy_arn}" ]]
then
   echo 'ERROR: testing get_managed_policy_arn with valid policy.'
   counter=$((counter +1))
fi

echo 'get_managed_policy_arn tests completed.' 

###########################################
## TEST 3: check_user_exists
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing argument.
#

set +e
check_user_exists > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_user_exists with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing user.
#

check_user_exists 'tech22' > /dev/null 2>&1
user_exists="${__RESULT}"
__RESULT=''

# false is expected
if [[ 'false' != "${user_exists}" ]]
then
   echo 'ERROR: testing check_user_exists with not existing user.'
   counter=$((counter +1))
fi

#
# Success.
#

aws iam create-user --user-name 'tech1' > /dev/null 2>&1 

check_user_exists 'tech1' > /dev/null 2>&1
user_exists="${__RESULT}"
__RESULT=''

if [[ 'true' != "${user_exists}" ]]
then
   echo 'ERROR: testing check_user_exists with valid user.'
   counter=$((counter +1))
fi

echo 'check_user_exists tests completed.'

###########################################
## TEST 3: get_user_arn
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing argument.
#

set +e
get_user_arn > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_user_arn with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing user.
#

get_user_arn 'tech22' > /dev/null 2>&1
user_arn="${__RESULT}"
__RESULT=''

# Empty string expected
if [[ -n "${user_arn}" ]]
then
   echo 'ERROR: testing get_user_arn with not existing user.'
   counter=$((counter +1))
fi

#
# Success.
#

aws iam create-user --user-name 'tech1' > /dev/null 2>&1 

get_user_arn 'tech22' > /dev/null 2>&1
user_arn="${__RESULT}"
__RESULT=''

if [[ -n "${user_arn}" ]]
then
   echo 'ERROR: testing get_user_arn with valid user.'
   counter=$((counter +1))
fi

echo 'get_user_arn tests completed.' 

###########################################
## TEST 3: check_user_exists
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing argument.
#

set +e
check_user_exists > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_user_exists with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing user.
#

check_user_exists 'tech22' > /dev/null 2>&1
user_exists="${__RESULT}"
__RESULT=''

# false is expected
if [[ 'false' != "${user_exists}" ]]
then
   echo 'ERROR: testing check_user_exists with not existing user.'
   counter=$((counter +1))
fi

#
# Success.
#

aws iam create-user --user-name 'tech1' > /dev/null 2>&1 

check_user_exists 'tech1' > /dev/null 2>&1
user_exists="${__RESULT}"
__RESULT=''

if [[ 'true' != "${user_exists}" ]]
then
   echo 'ERROR: testing check_user_exists with valid user.'
   counter=$((counter +1))
fi

echo 'check_user_exists tests completed.'

###########################################
## TEST 3: get_user_arn
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing argument.
#

set +e
get_user_arn > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_user_arn with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing user.
#

get_user_arn 'tech22' > /dev/null 2>&1
user_arn="${__RESULT}"
__RESULT=''

# Empty string expected
if [[ -n "${user_arn}" ]]
then
   echo 'ERROR: testing get_user_arn with not existing user.'
   counter=$((counter +1))
fi

#
# Success.
#

aws iam create-user --user-name 'tech1' > /dev/null 2>&1 

get_user_arn 'tech22' > /dev/null 2>&1
user_arn="${__RESULT}"
__RESULT=''

if [[ -n "${user_arn}" ]]
then
   echo 'ERROR: testing get_user_arn with valid user.'
   counter=$((counter +1))
fi

echo 'get_user_arn tests completed.' 

###########################################
## TEST 11: create_user
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing argument.
#

set +e
create_user > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_user with missing arguments.'
   counter=$((counter +1))
fi 

#
# Success.
#

set +e
create_user 'tech1' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_user.'
   counter=$((counter +1))
else 
   user_id="$(aws iam list-users --query "Users[? UserName=='tech1' ].UserId" \
       --output text)"
    
   if test -z "${user_id}"
   then
      echo 'ERROR: testing create_user, user not found.'
      counter=$((counter +1))
   fi
fi
 
#
# Same user twice.
#

set +e
create_user 'tech1' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing create_user twice.'
   counter=$((counter +1))
fi 

echo 'create_user tests completed.'   

__helper_clear_resources > /dev/null 2>&1 

###########################################
## TEST 10: delete_user
###########################################

__helper_clear_resources > /dev/null 2>&1 

# Create a user with a policy attached.
aws iam create-user --user-name 'tech1' > /dev/null 2>&1 
__helper_create_managed_policy 'Route-53-policy' > /dev/null 2>&1
policy_arn="${__RESULT}"
__RESULT=''
aws iam attach-user-policy --user-name 'tech1' --policy-arn "${policy_arn}" 

#
# Missing argument.
#

set +e
delete_user > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_user with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing user.
#

set +e
delete_user 'techxxx' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing delete_user with not existing user.'
   counter=$((counter +1))
fi 

#
# User with policy attached.
#

set +e
delete_user 'tech1' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_user with policy attached.'
   counter=$((counter +1))
else
    # Check the user has been deleted.
   user_id="$(aws iam list-users --query "Users[? UserName=='tech1' ].UserId" \
        --output text)"
    
   if test -n "${user_id}"
   then
      echo 'ERROR: testing delete_user.'
      counter=$((counter +1))
   fi 

   # Check the policy hasn't been canceled.
   policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].Arn" \
       --output text)"
    
   if test -z "${policy_arn}"
   then
      echo 'ERROR: testing delete_user, the policy has been canceled.'
      counter=$((counter +1))
   fi 
fi

#
# User without policy attached.
#

# Create a user without a policy attached.
aws iam create-user --user-name 'tech1' > /dev/null 2>&1 

set +e
delete_user 'tech1' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_user without policy attached.'
   counter=$((counter +1))
fi

echo 'delete_user tests completed.'

###########################################
## TEST 1: attach_managed_policy_to_user
###########################################

__helper_clear_resources > /dev/null 2>&1

# Create a user and a policy.
aws iam create-user --user-name 'tech1' > /dev/null 2>&1
__helper_create_managed_policy 'Route-53-policy' > /dev/null 2>&1

#
# Missing argument.
#

set +e
attach_managed_policy_to_user 'tech1' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing attach_managed_policy_to_user with missing arguments.'
   counter=$((counter +1))
fi

#
# Managed policy not found.
#

set +e
attach_managed_policy_to_user 'tech1' 'XXXX-53-policy' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]] 
then
   echo 'ERROR: testing attach_managed_policy_to_user with not existing policy.'
   counter=$((counter +1))
fi

#
# Attach policy successfully.
#

set +e
attach_managed_policy_to_user 'tech1' 'Route-53-policy' > /dev/null 2>&1 
exit_code=$?
set -e

if [[ 0 -ne "${exit_code}" ]] 
then
   echo 'ERROR: testing attach_managed_policy_to_user with existing policy.'
   counter=$((counter +1))
else
   policy_arn="$(aws iam list-attached-user-policies --user-name  'tech1' \
       --query "AttachedPolicies[? PolicyName=='Route-53-policy'].PolicyArn" --output text)"

   if test -z "${policy_arn}"
   then
      echo 'ERROR: testing attach_managed_policy_to_user, policy ARN not found.'
      counter=$((counter +1))
   fi       
fi

echo 'attach_managed_policy_to_user tests completed.'  

__helper_clear_resources > /dev/null 2>&1

#######################################################
## TEST 12: __build_route53_managed_policy_document
#######################################################

#
# Create a document policy for Route 53.
#

document_policy=''
__build_route53_managed_policy_document
document_policy="${__RESULT}"
__RESULT=''

## Validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${document_policy}"
then
    
    # Get the Version element.
    version="$(echo "${document_policy}" | jq -r '.Version')"

    if [[ '2012-10-17' != "${version}" ]]
    then
       echo "ERROR: testing __build_route53_managed_policy_document wrong Version element."
       counter=$((counter +1))
    fi
    
    # Get the Effect element.
    effect="$(echo "${document_policy}" | jq -r '.Statement[0].Effect')"
    
    if [[ 'Allow' != "${effect}" ]]
    then
       echo "ERROR: testing __build_route53_managed_policy_document wrong Effect element."
       counter=$((counter +1))
    fi
    
    # Get the first Action element.
    action="$(echo "${document_policy}" | jq -r '.Statement[0].Action[0]')"
    
    if [[ 'route53:DeleteTrafficPolicy' != "${action}" ]]
    then
       echo "ERROR: testing __build_route53_managed_policy_document wrong first Action element."
       counter=$((counter +1))
    fi
    
    # Get the second Action element.
    action="$(echo "${document_policy}" | jq -r '.Statement[0].Action[1]')"
    
    if [[ 'route53:CreateTrafficPolicy' != "${action}" ]]
    then
       echo "ERROR: testing __build_route53_managed_policy_document wrong second Action element."
       counter=$((counter +1))
    fi
    
    # Get the third Action element.
    action="$(echo "${document_policy}" | jq -r '.Statement[0].Action[2]')"
    
    if [[ 'sts:AssumeRole' != "${action}" ]]
    then
       echo "ERROR: testing __build_route53_managed_policy_document wrong third Action element."
       counter=$((counter +1))
    fi
    
    # Get the Resource element.
    resource="$(echo "${document_policy}" | jq -r '.Statement[0].Resource')"
    
    if [[ '*' != "${resource}" ]]
    then
       echo "ERROR: testing __build_route53_managed_policy_document wrong Resource element."
       counter=$((counter +1))
    fi       
else
    echo "ERROR: Failed to parse JSON __build_route53_managed_policy_document request batch."
    counter=$((counter +1))
fi

echo '__build_route53_managed_policy_document tests completed.'

###########################################
## TEST 13: create_managed_policy
###########################################

__helper_clear_resources > /dev/null 2>&1

#
# Missing argument.
#

set +e
create_managed_policy 'Route-53-policy' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_managed_policy with missing arguments.'
   counter=$((counter +1))
fi

#
# Create a policy successfully.
#

# Create the policy document.
__helper_create_managed_policy_document
policy_document="${__RESULT}"
__RESULT=''

set +e
create_managed_policy 'Route-53-policy' 'Route 53 create and delete records policy.' \
    "${policy_document}" > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_managed_policy with missing arguments.'
   counter=$((counter +1))
else
   # Check the policy.
   policy_name="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].PolicyName" \
       --output text)"   
   
   if [[ -z "${policy_name}" ]]
   then
      echo 'ERROR: testing create_managed_policy, policy not found.'
      counter=$((counter +1))
   fi
fi

#
# Create a policy twice.
#

# An error is expected.

set +e
create_managed_policy 'Route-53-policy' 'Route 53 create and delete records policy.' \
    "${policy_document}" > /dev/null 2>&1 
exit_code=$?
set -e


# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing create_managed_policy twice.'
   counter=$((counter +1))
fi

######## TODO
######## Verify the policy grants work.
######## TODO

echo 'create_managed_policy tests completed.'

__helper_clear_resources > /dev/null 2>&1 

###########################################
## TEST 14: delete_managed_policy
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing argument.
#

set +e
delete_managed_policy > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_managed_policy with missing arguments.'
   counter=$((counter +1))
fi

__helper_create_managed_policy 'Route-53-policy' > /dev/null 2>&1

#
# Delete a policy successfully.
#

delete_managed_policy 'Route-53-policy' > /dev/null 2>&1        

policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].Arn" --output text)"

# Empty string is expected.
if [[ -n "${policy_arn}" ]]
then
   echo 'ERROR: testing delete_managed_policy.'
   counter=$((counter +1))
fi

#
# Not existing policy.
#

set +e
delete_managed_policy 'xxxxx-53-policy' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing delete_managed_policy with not existing policy.'
   counter=$((counter +1))
fi

echo 'delete_managed_policy tests completed.'

##############################################################
## TEST 3: __build_route53_permission_managed_policy_document
##############################################################

#### TODO
#### TODO
#### TODO
#### TODO 

###########################################
## TEST 3: create_role
###########################################

#### TODO
#### TODO
#### TODO
#### TODO 

###########################################
## TEST 4: detach_managed_policy_from_user
###########################################

#### TODO
#### TODO
#### TODO
#### TODO  
   
##############################################
# Count the errors.
##############################################

echo

if [[ "${counter}" -gt 0 ]]
then
   echo "iam.sh script test completed with ${counter} errors."
else
   echo 'iam.sh script test successfully completed.'
fi

echo

