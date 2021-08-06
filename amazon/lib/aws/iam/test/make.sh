#!/usr/bin/bash

set +o errexit
set +o pipefail
set +o nounset
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

   declare -r policy_nm="${1}"
   declare -r policy_desc='Create/delete Route 53 records.'
   local policy_document=''
   local policy_arn=''

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
                
   policy_arn="$(aws iam create-policy \
       --policy-name "${policy_nm}" --description "${policy_desc}" \
       --policy-document "${policy_document}" --query "Policy.Arn" --output text)"  

   eval "__RESULT='${policy_arn}'"
   
   return 0
}

function __helper_clear_resources()
{
   local policy_arn=''
   local group_id=''
   local user_id=''
   
   group_id="$(aws iam list-groups --query "Groups[? GroupName=='techies' ].GroupId" --output text)"
   policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].Arn" \
       --output text)"
   user_id="$(aws iam list-users --query "Users[? UserName=='tech1'].UserId" --output text)"       
   
   if [[ -n "${group_id}" ]]
   then
      if [[ -n "${user_id}" ]]
      then
         set +e
         aws iam remove-user-from-group --user-name 'tech1' --group-name 'techies'
         set -e
         
         echo 'User removed from group.'
      fi
      
      if [[ -n "${policy_arn}" ]]
      then
         set +e
         aws iam detach-group-policy --group-name 'techies' --policy-arn "${policy_arn}"
         set -e
         
         echo 'Policy detached from group.'
      fi
      
      aws iam delete-group --group-name 'techies' > /dev/null 2>&1
   
      echo 'Group deleted.'
   fi

   if [[ -n "${user_id}" ]]
   then
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

###########################################
## TEST 1: delete_group
###########################################

__helper_clear_resources > /dev/null 2>&1

# Create a user group with one user and one policy.
aws iam create-group --group-name 'techies' > /dev/null
aws iam create-user --user-name 'tech1' > /dev/null 
aws iam add-user-to-group --user-name 'tech1' --group-name 'techies'
__helper_create_policy 'Route-53-policy' > /dev/null 2>&1
policy_arn="${__RESULT}"
aws iam attach-group-policy --group-name 'techies' --policy-arn "${policy_arn}"

#
# Missing argument.
#

set +e
delete_group > /dev/null
exit_code=$?
set -e

if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing delete_group with missing argument.'
   counter=$((counter +1))
fi

#
# Group with user and policy.
# 

set +e
delete_group 'techies' > /dev/null
exit_code=$?
set -e

# Check the group has been deleted.
group_id="$(aws iam list-groups --query "Groups[? GroupName=='techies' ].GroupId" --output text)"

if test -n "${group_id}"
then
   echo 'ERROR: testing delete_group, the group hasn''t been canceled.'
   counter=$((counter +1))
fi 

# Check the policy hasn't been canceled.
policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].Arn" \
    --output text)"
    
if test -z "${policy_arn}"
then
   echo 'ERROR: testing delete_group, the policy has been canceled.'
   counter=$((counter +1))
fi     

# Check the user hasn't been canceled.
user_id="$(aws iam list-users --query "Users[? UserName=='tech1'].UserId" --output text)" 
    
if test -z "${user_id}"
then
   echo 'ERROR: testing delete_group, the user has been canceled.'
   counter=$((counter +1))
fi  

echo 'delete_group tests completed.'   

###########################################
## TEST 2: __detach_policy_from_group
###########################################

__helper_clear_resources > /dev/null 2>&1

# Create a group and attach a policy.
aws iam create-group --group-name 'techies' > /dev/null
__helper_create_policy 'Route-53-policy' > /dev/null 2>&1
policy_arn="${__RESULT}"
aws iam attach-group-policy --group-name 'techies' --policy-arn "${policy_arn}"

__detach_policy_from_group 'techies' 'Route-53-policy' > /dev/null

policy_arn="$(aws iam list-attached-group-policies --group-name  'techies' \
    --query "AttachedPolicies[? PolicyName=='Route-53-policy'].PolicyArn" --output text)"

if test -n "${policy_arn}"
then
   echo 'ERROR: testing __detach_policy_from_group.'
   counter=$((counter +1))
fi

echo '__detach_policy_from_group tests completed.'  

###########################################
## TEST 3: __get_policy_arn
###########################################

__helper_clear_resources > /dev/null 2>&1

# Create a policy
__helper_create_policy 'Route-53-policy' > /dev/null 2>&1

__get_policy_arn 'Route-53-policy'
policy_arn="${__RESULT}"

if test -z "${policy_arn}"
then
   echo 'ERROR: testing __get_policy_arn.'
   counter=$((counter +1))
fi

echo '__get_policy_arn tests completed.' 

###########################################
## TEST 4: create_group
###########################################

__helper_clear_resources > /dev/null 2>&1 

create_group 'techies' > /dev/null
group_arn="${__RESULT}"

if test -z "${group_arn}"
then
   echo 'ERROR: testing create_group, group ARN not found.'
   counter=$((counter +1))
fi 

# Check the group has been created.
group_id="$(aws iam list-groups --query "Groups[? GroupName=='techies' ].GroupId" --output text)"

if test -z "${group_id}"
then
   echo 'ERROR: testing create_group, the group hasn''t been created.'
   counter=$((counter +1))
fi 

echo 'create_group tests completed.'    

###########################################
## TEST 5: __remove_user_from_group
###########################################

__helper_clear_resources > /dev/null 2>&1 

# Create a user and add it to a group.
aws iam create-user --user-name 'tech1' > /dev/null 
aws iam create-group --group-name 'techies' > /dev/null
aws iam add-user-to-group --user-name 'tech1' --group-name 'techies'

__remove_user_from_group 'techies' 'tech1' > /dev/null

group_nm="$(aws iam list-groups-for-user --user-name 'tech1' --query Groups[].GroupName --output text)" 
      
if test -n "${group_nm}" 
then
    echo 'ERROR: testing __remove_user_from_group.'
   counter=$((counter +1))
fi

echo '__remove_user_from_group tests completed.'

###########################################
## TEST 6: add_user_to_group
###########################################

__helper_clear_resources > /dev/null 2>&1 

# Create a user and a group.
aws iam create-user --user-name 'tech1' > /dev/null 
aws iam create-group --group-name 'techies' > /dev/null

add_user_to_group 'tech1' 'techies' > /dev/null

group_nm="$(aws iam list-groups-for-user --user-name 'tech1' --query Groups[].GroupName --output text)" 
      
if test -z "${group_nm}" 
then
    echo 'ERROR: testing add_user_to_group.'
   counter=$((counter +1))
fi

echo 'add_user_to_group tests completed.' 

###########################################
## TEST 7: delete_user
###########################################

__helper_clear_resources > /dev/null 2>&1 

aws iam create-user --user-name 'tech1' > /dev/null 
       
delete_user 'tech1'       

user_id="$(aws iam list-users --query "Users[? UserName=='tech1' ].UserId" \
     --output text)"
    
if test -n "${user_id}"
then
   echo 'ERROR: testing delete_user.'
   counter=$((counter +1))
fi 

echo 'delete_user tests completed.'   

###########################################
## TEST 8: create_user
###########################################

create_user 'tech1'

user_id="$(aws iam list-users --query "Users[? UserName=='tech1' ].UserId" \
     --output text)"
    
if test -z "${user_id}"
then
   echo 'ERROR: testing create_user, user not found.'
   counter=$((counter +1))
fi 

echo 'create_user tests completed.'   

__helper_clear_resources > /dev/null 2>&1 

#################################################
## TEST 9: __build_route53_policy_document
#################################################

#
# Create a document policy for Route 53.
#

document_policy=''
__build_route53_policy_document
document_policy="${__RESULT}"

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
## TEST 10: create_route53_policy
###########################################

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
policy_arn=''
create_route53_policy 'Route-53-policy'
policy_arn="${__RESULT}"

if test -z "${policy_arn}"
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

policy_arn=''
create_route53_policy 'Route-53-policy'
policy_arn="${__RESULT}"

if test -n "${policy_arn}"
then
   echo 'ERROR: testing create_route53_policy twice.'
   counter=$((counter +1))
fi

####### TODO
######## Verify the policy.
#######

echo 'create_route53_policy tests completed.'

__helper_clear_resources > /dev/null 2>&1 

###########################################
## TEST 11: delete_policy
###########################################

__helper_create_policy 'Route-53-policy' > /dev/null 2>&1

#
# Missing argument.
#

set +e
delete_policy > /dev/null
exit_code=$?
set -e

# An error is expected.
if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing delete_policy with missing argument.'
   counter=$((counter +1))
fi

#
# Delete a policy successfully.
#

delete_policy 'Route-53-policy'

policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='Route-53-policy' ].Arn" --output text)"

# Emptry string is expected.
if [[ -n "${policy_arn}" ]]
then
   echo 'ERROR: testing delete_policy.'
   counter=$((counter +1))
fi

echo 'delete_policy tests completed.'
   
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

