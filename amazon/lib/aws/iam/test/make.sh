#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace
 
counter=0; __RESULT='';
ROLE_NM='EC2-assume-role'
POLICY_NM='Route-53-policy'
PROFILE_NM='EC2-instance-profile'

##
## Functions used to handle test data.
##

function __helper_create_role_policy_document()
{
   local policy_document=''

   policy_document=$(cat <<-'EOF' 
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}     
	EOF
   )
    
   __RESULT="${policy_document}"
   
   return 0
}

function __helper_create_permission_policy_document()
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
   
   __RESULT="${policy_document}"
   
   return 0
}

function __helper_create_permission_policy()
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

   __helper_create_permission_policy_document
   policy_document="${__RESULT}"      
                
   policy_arn="$(aws iam create-policy \
       --policy-name "${policy_nm}" --description "${policy_desc}" \
       --policy-document "${policy_document}" --query "Policy.Arn" --output text)"  

   __RESULT="${policy_arn}"
   
   return 0
}

function __helper_clear_resources()
{
   local policy_arn=''
   
   # Clear the global __RESULT variable.
   __RESULT=''
   
   #
   # Role.
   #
   
   role_id="$(aws iam list-roles \
       --query "Roles[? RoleName=='${ROLE_NM}'].Arn" --output text)" 
       
   if [[ -n "${role_id}" ]]
   then  
      policy_arn="$(aws iam list-attached-role-policies --role-name  "${ROLE_NM}" \
          --query "AttachedPolicies[? PolicyName=='${POLICY_NM}' ].PolicyArn" --output text)"
          
      if [[ -n "${policy_arn}" ]]
      then 
         aws iam detach-role-policy --role-name "${ROLE_NM}" --policy-arn "${policy_arn}"
         
         echo 'Policy detached from from role.'
      fi 
      
      instance_profiles="$(aws iam list-instance-profiles-for-role --role-name "${ROLE_NM}" \
          --query "InstanceProfiles[].InstanceProfileName" --output text)"
   
      for profile_nm in ${instance_profiles}
      do
         aws iam remove-role-from-instance-profile --instance-profile-name "${profile_nm}" \
             --role-name "${ROLE_NM}"
             
         echo 'Role removed from instance profile.'      
      done       
      
      aws iam delete-role --role-name "${ROLE_NM}" > /dev/null
   
      echo 'Role deleted.'
   fi
   
   #
   # Permission policy.
   #   
   
   policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='${POLICY_NM}' ].Arn" \
       --output text)"
   
   if [[ -n "${policy_arn}" ]]
   then
      aws iam delete-policy --policy-arn "${policy_arn}"
   
      echo 'Policy deleted'
   fi
   
   #
   # Instance profile.
   # 
   
   instance_profiles_arn="$(aws iam list-instance-profiles \
       --query "InstanceProfiles[? InstanceProfileName=='${PROFILE_NM}' ].Arn" --output text)"
   
   if [[ -n "${instance_profiles_arn}" ]]
   then
      aws iam delete-instance-profile --instance-profile-name "${PROFILE_NM}"
   
      echo 'Instance profile deleted'
   fi
   
   echo 'Test resources cleared.'   
   
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

trap "__helper_clear_resources" EXIT

#######################################################
## TEST: build_route53_permission_policy_document
#######################################################

document_policy=''; version=''; effect=''; action=''; resource='';

#
# Create a document policy.
#

build_route53_permission_policy_document
document_policy="${__RESULT}"

## Validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${document_policy}"
then
    
    # Get the Version element.
    version="$(echo "${document_policy}" | jq -r '.Version')"

    if [[ '2012-10-17' != "${version}" ]]
    then
       echo "ERROR: testing build_route53_permission_policy_document wrong Version element."
       counter=$((counter +1))
    fi
    
    # Get the Effect element.
    effect="$(echo "${document_policy}" | jq -r '.Statement[0].Effect')"
    
    if [[ 'Allow' != "${effect}" ]]
    then
       echo "ERROR: testing build_route53_permission_policy_document wrong Effect element."
       counter=$((counter +1))
    fi
    
    # Get the first Action element.
    action="$(echo "${document_policy}" | jq -r '.Statement[0].Action[0]')"
    
    if [[ 'route53:*' != "${action}" ]]
    then
       echo "ERROR: testing build_route53_permission_policy_document wrong first Action element."
       counter=$((counter +1))
    fi
    
    # Get the second Action element.
    action=''
    action="$(echo "${document_policy}" | jq -r '.Statement[0].Action[1]')"
    
    if [[ 'route53domains:*' != "${action}" ]]
    then
       echo "ERROR: testing build_route53_permission_policy_document wrong second Action element."
       counter=$((counter +1))
    fi
    
    # Get the third Action element.
    action=''
    action="$(echo "${document_policy}" | jq -r '.Statement[0].Action[2]')"
    
    if [[ 'sts:AssumeRole' != "${action}" ]]
    then
       echo "ERROR: testing build_route53_permission_policy_document wrong third Action element."
       counter=$((counter +1))
    fi
    
    # Get the Resource element.
    resource="$(echo "${document_policy}" | jq -r '.Statement[0].Resource')"
    
    if [[ '*' != "${resource}" ]]
    then
       echo "ERROR: testing build_route53_permission_policy_document wrong Resource element."
       counter=$((counter +1))
    fi       
else
    echo "ERROR: Failed to parse JSON build_route53_permission_policy_document request batch."
    counter=$((counter +1))
fi

echo 'build_route53_permission_policy_document tests completed.'

###########################################################
## TEST: build_assume_role_policy_document_for_ec2_entities
###########################################################

version=''; effect=''; action=''; service=''; document_policy='';

#
# Create a document policy.
#

build_assume_role_policy_document_for_ec2_entities
document_policy="${__RESULT}"

## Validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${document_policy}"
then
    
    # Get the Version element.
    version="$(echo "${document_policy}" | jq -r '.Version')"

    if [[ '2012-10-17' != "${version}" ]]
    then
       echo "ERROR: testing build_assume_role_policy_document_for_ec2_entities wrong Version element."
       counter=$((counter +1))
    fi
    
    # Get the Effect element.
    effect="$(echo "${document_policy}" | jq -r '.Statement.Effect')"
    
    if [[ 'Allow' != "${effect}" ]]
    then
       echo "ERROR: testing build_assume_role_policy_document_for_ec2_entities wrong Effect element."
       counter=$((counter +1))
    fi
    
    # Get the Action element.
    action="$(echo "${document_policy}" | jq -r '.Statement.Action')"
    
    if [[ 'sts:AssumeRole' != "${action}" ]]
    then
       echo "ERROR: testing build_assume_role_policy_document_for_ec2_entities wrong Action element."
       counter=$((counter +1))
    fi
    
    # Get the Service element.
    service="$(echo "${document_policy}" | jq -r '.Statement.Principal.Service')"
    
    if [[ 'ec2.amazonaws.com' != "${service}" ]]
    then
       echo "ERROR: testing build_assume_role_policy_document_for_ec2_entities wrong second Service element."
       counter=$((counter +1))
    fi      
else
    echo "ERROR: Failed to parse JSON build_assume_role_policy_document_for_ec2_entities request batch."
    counter=$((counter +1))
fi

echo 'build_assume_role_policy_document_for_ec2_entities tests completed.' 

##############################################################
## TEST: check_role_has_permission_policy_attached
##############################################################

__helper_clear_resources > /dev/null 2>&1 
exit_code=0; policy_attached=''; policy_arn=''; policy_document='';

# Create a role with a permission policy attached.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 
__helper_create_permission_policy "${POLICY_NM}" > /dev/null 2>&1
policy_arn="${__RESULT}"

aws iam attach-role-policy --role-name "${ROLE_NM}" --policy-arn "${policy_arn}" 

#
# Missing argument.
#

set +e
check_role_has_permission_policy_attached "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached with missing arguments.'
   counter=$((counter +1))
fi

#
# Not existing role.
#

set +e
check_role_has_permission_policy_attached 'xxx-assume-role' "${POLICY_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached with not existing role.'
   counter=$((counter +1))
fi

policy_attached="${__RESULT}"

# And empty string is expected.
if [[ -n "${policy_attached}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached with not existing role, policy is attached.'
   counter=$((counter +1))
fi

#
# Not existing policy.
#

set +e
check_role_has_permission_policy_attached "${ROLE_NM}" 'xxxxx-53-policy' > /dev/null 2>&1
exit_code=$?
set -e

policy_attached="${__RESULT}"

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached with not existing policy.'
   counter=$((counter +1))
fi

# And empty string is expected.
if [[ -n "${policy_attached}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached with not existing policy.'
   counter=$((counter +1))
fi

#
# Policy attached.
#

set +e
check_role_has_permission_policy_attached "${ROLE_NM}" "${POLICY_NM}" > /dev/null 2>&1
exit_code=$?
set -e

policy_attached="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached with policy attached.'
   counter=$((counter +1))
fi

# true is expected.
if [[ 'true' != "${policy_attached}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached.'
   counter=$((counter +1))
fi

#
# Policy detached.
#

# Detach the policy from the role.
policy_arn="$(aws iam list-attached-role-policies --role-name  "${ROLE_NM}" \
          --query "AttachedPolicies[? PolicyName=='${POLICY_NM}' ].PolicyArn" --output text)"
aws iam detach-role-policy --role-name "${ROLE_NM}" --policy-arn "${policy_arn}" > /dev/null

set +e
check_role_has_permission_policy_attached "${ROLE_NM}" "${POLICY_NM}" > /dev/null 2>&1
exit_code=$?
set -e

policy_attached="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached with policy detached.'
   counter=$((counter +1))
fi

# false is expected.
if [[ 'false' != "${policy_attached}" ]]
then
   echo 'ERROR: testing check_role_has_permission_policy_attached.'
   counter=$((counter +1))
fi

echo 'check_role_has_permission_policy_attached tests completed.'

###########################################
## TEST: get_role_arn
###########################################

__helper_clear_resources > /dev/null 2>&1 
exit_code=0; role_arn=''; policy_document=''; 

# Create a role
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 

#
# Missing argument.
#

set +e
get_role_arn > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_role_arn with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing role.
#

set +e
get_role_arn 'XXX-assume-role' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_role_arn with not existing role.'
   counter=$((counter +1))
fi 

role_arn="${__RESULT}"

# Empty string expected
if [[ -n "${role_arn}" ]]
then
   echo 'ERROR: testing get_role_arn with not existing role.'
   counter=$((counter +1))
fi

#
# Success.
#

role_arn='' 

set +e
get_role_arn "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_role_arn.'
   counter=$((counter +1))
fi 

role_arn="${__RESULT}"

if [[ -z "${role_arn}" ]]
then
   echo 'ERROR: testing get_role_arn with valid role, role not found.'
   counter=$((counter +1))
fi

echo 'get_role_arn tests completed.'

###########################################
## TEST: get_instance_profile_id
###########################################

__helper_clear_resources > /dev/null 2>&1
exit_code=0; profile_id='';

# Create an instance profile.
aws iam create-instance-profile --instance-profile-name "${PROFILE_NM}" > /dev/null 2>&1

#
# Missing argument.
#

set +e
get_instance_profile_id > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_instance_profile_id with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing profile.
#  

set +e
get_instance_profile_id 'XXX-instance-profile' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_instance_profile_id with not existing profile.'
   counter=$((counter +1))
fi

profile_id="${__RESULT}"

if [[ -n "${profile_id}" ]]
then
   echo 'ERROR: testing get_instance_profile_id with not existing profile.'
   counter=$((counter +1))
fi

#
# Success.
#

profile_id=''

set +e
get_instance_profile_id "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

profile_id="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_instance_profile_id.'
   counter=$((counter +1))
fi

if [[ -z "${profile_id}" ]]
then
   echo 'ERROR: testing get_instance_profile_id with existing profile.'
   counter=$((counter +1))
fi

echo 'get_instance_profile_id tests completed.' 

###########################################
## TEST: check_instance_profile_exists
###########################################

__helper_clear_resources > /dev/null 2>&1
exit_code=0; profile_exists='';

# Create an instance profile.
aws iam create-instance-profile --instance-profile-name "${PROFILE_NM}" > /dev/null 2>&1

#
# Missing argument.
#

set +e
check_instance_profile_exists > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_profile_exists with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing profile.
#  

set +e
check_instance_profile_exists 'XXX-instance-profile' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_profile_exists with not existing profile.'
   counter=$((counter +1))
fi

profile_exists="${__RESULT}"

if [[ 'false' != "${profile_exists}" ]]
then
   echo 'ERROR: testing check_instance_profile_exists with not existing profile.'
   counter=$((counter +1))
fi

#
# Success.
#

profile_exists=''

set +e
check_instance_profile_exists "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

profile_exists="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_profile_exists.'
   counter=$((counter +1))
fi

if [[ 'true' != "${profile_exists}" ]]
then
   echo 'ERROR: testing check_instance_profile_exists with existing profile.'
   counter=$((counter +1))
fi

echo 'check_instance_profile_exists tests completed.' 

####################################################
## TEST: check_instance_profile_has_role_associated
####################################################

__helper_clear_resources > /dev/null 2>&1
has_role=''; exit_code=0; policy_document=''; role_nm='';

# Create a role.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" \
    --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 

# Create an instance profile and attach the role to it.
aws iam create-instance-profile --instance-profile-name "${PROFILE_NM}" > /dev/null 2>&1
aws iam add-role-to-instance-profile --instance-profile-name "${PROFILE_NM}" \
       --role-name "${ROLE_NM}" > /dev/null 2>&1
    
#
# Missing argument.
#

set +e
check_instance_profile_has_role_associated "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_profile_has_role_associated with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing profile.
#  

set +e
check_instance_profile_has_role_associated 'XXX-instance-profile' "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_profile_has_role_associated with not existing profile.'
   counter=$((counter +1))
fi

#
# Not existing role.
#  

set +e
check_instance_profile_has_role_associated "${PROFILE_NM}" 'XXX-assume-role' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_profile_has_role_associated  with not existing role.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
check_instance_profile_has_role_associated "${PROFILE_NM}" "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

has_role="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_profile_has_role_associated with role associated.'
   counter=$((counter +1))
fi

if [[ 'true' != "${has_role}" ]]
then
   echo 'ERROR: testing check_instance_profile_has_role_associated, role not found.'
   counter=$((counter +1))
fi

#
# Role not associated.
#

has_role=''

# Detach the role.
aws iam remove-role-from-instance-profile --instance-profile-name "${PROFILE_NM}" \
    --role-name "${ROLE_NM}"
    
set +e
check_instance_profile_has_role_associated "${PROFILE_NM}" "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

has_role="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_profile_has_role_associated with role not associated.'
   counter=$((counter +1))
fi

if [[ 'false' != "${has_role}" ]]
then
   echo 'ERROR: testing check_instance_profile_has_role_associated.'
   counter=$((counter +1))
fi

echo 'check_instance_profile_has_role_associated tests completed.' 

###########################################
## TEST: associate_role_to_instance_profile
###########################################

__helper_clear_resources > /dev/null 2>&1
role_arn=''; role_nm=''; exit_code=0; policy_document=''; 

# Create a role.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" \
    --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 

# Create an instance profile.
aws iam create-instance-profile --instance-profile-name "${PROFILE_NM}" > /dev/null 2>&1
    
#
# Missing argument.
#

set +e
associate_role_to_instance_profile "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing associate_role_to_instance_profile with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing profile.
#  

set +e
associate_role_to_instance_profile 'XXX-instance-profile' "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing associate_role_to_instance_profile with not existing profile.'
   counter=$((counter +1))
fi

#
# Not existing role.
#  

set +e
associate_role_to_instance_profile "${PROFILE_NM}" 'XXX-assume-role' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing associate_role_to_instance_profile  with not existing role.'
   counter=$((counter +1))
fi
    
#
# Success.
#

set +e
associate_role_to_instance_profile "${PROFILE_NM}" "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing associate_role_to_instance_profile.'
   counter=$((counter +1))
fi

# Check the association.
role_nm="$(aws iam list-instance-profiles \
    --query "InstanceProfiles[? InstanceProfileName == '${PROFILE_NM}' ].Roles[].RoleName" \
    --output text)"

if [[ "${ROLE_NM}" != "${role_nm}" ]]
then
   echo 'ERROR: testing associate_role_to_instance_profile.'
   counter=$((counter +1))
fi

#
# Associate twice.
#

set +e
associate_role_to_instance_profile "${PROFILE_NM}" "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing associate_role_to_instance_profile twice.'
   counter=$((counter +1))
fi

echo 'associate_role_to_instance_profile tests completed.'   

###########################################
## TEST: create_role
###########################################

__helper_clear_resources > /dev/null 2>&1
policy_document=''; role_arn=''; exit_code=0;

# Create a role policy document for the role.
__helper_create_role_policy_document
policy_document="${__RESULT}"

#
# Missing argument.
#

set +e
create_role "${ROLE_NM}" 'Route 53 test role' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_role with missing arguments.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
create_role "${ROLE_NM}" 'Route 53 test role' "${policy_document}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_role.'
   counter=$((counter +1))
fi

# Check the role.
role_arn="$(aws iam list-roles --query "Roles[? RoleName=='${ROLE_NM}' ].Arn" --output text)"
       
if test -z "${role_arn}"
then
   echo 'ERROR: testing create_role, role not found.'
   counter=$((counter +1))
fi 
 
#
# Same role twice.
#

set +e
create_role "${ROLE_NM}" 'Route 53 test role' "${policy_document}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing create_role twice.'
   counter=$((counter +1))
fi 

echo 'create_role tests completed.'

#############################################
## TEST: __detach_permission_policy_from_role
#############################################

__helper_clear_resources > /dev/null 2>&1
exit_code=0; policy_arn='';

# Create a role and a permission policy attached.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 
__helper_create_permission_policy "${POLICY_NM}" > /dev/null 2>&1
policy_arn="${__RESULT}"

aws iam attach-role-policy --role-name "${ROLE_NM}" --policy-arn "${policy_arn}" > /dev/null    

#
# Missing argument.
#

set +e
__detach_permission_policy_from_role "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing __detach_permission_policy_from_role with missing arguments.'
   counter=$((counter +1))
fi

#
# Not existing policy.
#

set +e
__detach_permission_policy_from_role "${ROLE_NM}" 'XXXX-53-policy' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]] 
then
   echo 'ERROR: testing __detach_permission_policy_from_role with not existing policy.'
   counter=$((counter +1))
fi

#
# Not existing role.
#

set +e
__detach_permission_policy_from_role 'xxx-assume-role' "${POLICY_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]] 
then
   echo 'ERROR: testing __detach_permission_policy_from_role with not existing role.'
   counter=$((counter +1))
fi

#
# Detach policy successfully.
#

set +e
__detach_permission_policy_from_role "${ROLE_NM}" "${POLICY_NM}" > /dev/null 2>&1 
exit_code=$?
set -e

if [[ 0 -ne "${exit_code}" ]] 
then
   echo 'ERROR: testing __detach_permission_policy_from_role.'
   counter=$((counter +1))
else
   # Check the policy hasn't been deleted.
   policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='${POLICY_NM}' ].Arn" --output text)"
   
   if test -z "${policy_arn}"
   then
      echo 'ERROR: testing __detach_permission_policy_from_role, policy has been deleted.'
      counter=$((counter +1))
   else
       # Check the policy isn't attached to the role.
       policy_arn=''
       policy_arn="$(aws iam list-attached-role-policies --role-name  "${ROLE_NM}" \
          --query "AttachedPolicies[? PolicyName=='${POLICY_NM}' ].PolicyArn" --output text)"
       
       if test -n "${policy_arn}"
       then
          echo 'ERROR: testing __detach_permission_policy_from_role, policy still attached to the role.'
          counter=$((counter +1))
       fi 
   fi         
fi

echo '__detach_permission_policy_from_role tests completed.'

###########################################
## TEST: attach_permission_policy_to_role
###########################################

__helper_clear_resources > /dev/null 2>&1
exit_code=0; policy_arn=''; policy_document='';

# Create a role and a permission policy.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 
__helper_create_permission_policy "${POLICY_NM}" > /dev/null 2>&1

#
# Missing argument.
#

set +e
attach_permission_policy_to_role "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing attach_permission_policy_to_role with missing arguments.'
   counter=$((counter +1))
fi

#
# Not existing policy.
#

set +e
attach_permission_policy_to_role "${ROLE_NM}" 'XXXX-53-policy' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]] 
then
   echo 'ERROR: testing attach_permission_policy_to_role with not existing policy.'
   counter=$((counter +1))
fi

#
# Not existing role.
#

set +e
attach_permission_policy_to_role 'xxx-assume-role' "${POLICY_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]] 
then
   echo 'ERROR: testing attach_permission_policy_to_role with not existing role.'
   counter=$((counter +1))
fi

#
# Attach policy successfully.
#

set +e
attach_permission_policy_to_role "${ROLE_NM}" "${POLICY_NM}" > /dev/null 2>&1 
exit_code=$?
set -e

if [[ 0 -ne "${exit_code}" ]] 
then
   echo 'ERROR: testing attach_permission_policy_to_role with existing policy.'
   counter=$((counter +1))
else
   policy_arn="$(aws iam list-attached-role-policies --role-name  "${ROLE_NM}" \
       --query "AttachedPolicies[? PolicyName=='${POLICY_NM}' ].PolicyArn" --output text)"

   if test -z "${policy_arn}"
   then
      echo 'ERROR: testing attach_permission_policy_to_role, policy not found.'
      counter=$((counter +1))
   fi       
fi

echo 'attach_permission_policy_to_role tests completed.'  

__helper_clear_resources > /dev/null 2>&1

###########################################
## TEST: create_instance_profile
###########################################

__helper_clear_resources > /dev/null 2>&1
exit_code=0; instance_profile_id='';

#
# Missing argument.
#

set +e
create_instance_profile > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_instance_profile with missing arguments.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
create_instance_profile "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_instance_profile.'
   counter=$((counter +1))
fi 

# Check the instance profile.
instance_profile_id="$(aws iam list-instance-profiles \
    --query "InstanceProfiles[? InstanceProfileName=='${PROFILE_NM}' ].InstanceProfileId" --output text)"

if [[ -z "${instance_profile_id}" ]]
then
   echo 'ERROR: testing create_instance_profile, the instance profile has not been created.'
   counter=$((counter +1))
fi
   
#
# Create twice.
#

set +e
create_instance_profile "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing create_instance_profile twice.'
   counter=$((counter +1))
fi 

echo 'create_instance_profile tests completed.'

###########################################
## TEST: delete_instance_profile
###########################################

__helper_clear_resources > /dev/null 2>&1 
exit_code=0; instance_profile_id=''; role_nm=''; role_id='';

# Create a role and attach it to an instance profile.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" \
    --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 

# Create an instance profile and attach the role to it.
aws iam create-instance-profile --instance-profile-name "${PROFILE_NM}" > /dev/null 2>&1
aws iam  add-role-to-instance-profile --instance-profile-name "${PROFILE_NM}" \
    --role-name "${ROLE_NM}" 

#
# Missing argument.
#

set +e
delete_instance_profile > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_instance_profile with missing arguments.'
   counter=$((counter +1))
fi

#
# Not existing instance profile.
#

set +e
delete_instance_profile 'XXX-instance-profile' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing delete_instance_profile with not existing profile.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
delete_instance_profile "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_instance_profile.'
   counter=$((counter +1))
fi 

# Check the role hasn't been deleted.
role_id="$(aws iam list-roles \
       --query "Roles[? RoleName=='${ROLE_NM}'].Arn" --output text)" 
       
if [[ -z "${role_id}" ]]
then
   echo 'ERROR: testing delete_instance_profile, the role has been deleted.'
   counter=$((counter +1))
fi       

# Check the role isn't attached to the profile.
role_nm="$(aws iam list-instance-profiles \
    --query "InstanceProfiles[? InstanceProfileName=='${PROFILE_NM}' ].Roles[].RoleName" --output text)"

if [[ "${ROLE_NM}" == "${role_nm}" ]]
then
   echo 'ERROR: testing delete_instance_profile.'
   counter=$((counter +1))
fi

# Check the instance profile.
instance_profile_id="$(aws iam list-instance-profiles \
    --query "InstanceProfiles[? InstanceProfileName=='${PROFILE_NM}' ].InstanceProfileId" --output text)"

if [[ -n "${instance_profile_id}" ]]
then
   echo 'ERROR: testing delete_instance_profile, the instance profile has not been canceled.'
   counter=$((counter +1))
fi
   
#
# Remove twice.
#

set +e
delete_instance_profile "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing delete_instance_profile twice.'
   counter=$((counter +1))
fi 

echo 'delete_instance_profile tests completed.'

###########################################
## TEST: check_role_exists
###########################################

__helper_clear_resources > /dev/null 2>&1 
exit_code=0; role_exists=''; policy_document='';

# Create a role and attach it to an instance profile.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" \
    --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 
    
#
# Missing argument.
#

set +e
check_role_exists > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_role_exists with missing arguments.'
   counter=$((counter +1))
fi    

#
# Not existing role.
#

set +e
check_role_exists 'XXX-assume-role' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_role_exists with not existing role.'
   counter=$((counter +1))
fi

role_exists="${__RESULT}"

if [[ 'false' != "${role_exists}" ]]
then
   echo 'ERROR: testing check_role_exists with not existing role.'
   counter=$((counter +1))
fi

#
# Success.
#
role_exists=''

set +e
check_role_exists "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_role_exists with existing role.'
   counter=$((counter +1))
fi

role_exists="${__RESULT}"

if [[ 'true' != "${role_exists}" ]]
then
   echo 'ERROR: testing check_role_exists with existing role.'
   counter=$((counter +1))
fi

echo 'check_role_exists tests completed.'      

############################################
## TEST: __remove_role_from_instance_profile
############################################

__helper_clear_resources > /dev/null 2>&1
instance_profile_id=''; role_nm=''; role_id=''; exit_code=0; 

# Create a role and attach it to an instance profile.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" \
    --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 

# Create an instance profile and attach the role to it.
aws iam create-instance-profile --instance-profile-name "${PROFILE_NM}" > /dev/null 2>&1
aws iam  add-role-to-instance-profile --instance-profile-name "${PROFILE_NM}" --role-name "${ROLE_NM}" 
   
#
# Missing argument.
#

set +e
__remove_role_from_instance_profile > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing __remove_role_from_instance_profile with missing arguments.'
   counter=$((counter +1))
fi

#
# Not existing instance profile.
#

set +e
__remove_role_from_instance_profile 'XXX-instance-profile' "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing __remove_role_from_instance_profile with not existing instance profile.'
   counter=$((counter +1))
fi  

#
# Not existing role.
#

set +e
__remove_role_from_instance_profile "${PROFILE_NM}" 'XXX-assume-role' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing __remove_role_from_instance_profile with not existing role.'
   counter=$((counter +1))
fi   

#
# Success.
#

set +e
__remove_role_from_instance_profile "${PROFILE_NM}" "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing __remove_role_from_instance_profile.'
   counter=$((counter +1))
fi 

# Check the role hasn't been deleted.
role_id="$(aws iam list-roles \
       --query "Roles[? RoleName=='${ROLE_NM}'].Arn" --output text)" 
       
if [[ -z "${role_id}" ]]
then
   echo 'ERROR: testing __remove_role_from_instance_profile, the role has been deleted.'
   counter=$((counter +1))
fi       

# Check the role isn't attached to the profile.
role_nm="$(aws iam list-instance-profiles \
    --query "InstanceProfiles[? InstanceProfileName=='${PROFILE_NM}' ].Roles[].RoleName" --output text)"

if [[ "${ROLE_NM}" == "${role_nm}" ]]
then
   echo 'ERROR: testing __remove_role_from_instance_profile.'
   counter=$((counter +1))
fi

# Check the instance profile.
instance_profile_id="$(aws iam list-instance-profiles \
    --query "InstanceProfiles[? InstanceProfileName=='${PROFILE_NM}' ].InstanceProfileId" --output text)"

if [[ -z "${instance_profile_id}" ]]
then
   echo 'ERROR: testing __remove_role_from_instance_profile, the instance profile has been canceled.'
   counter=$((counter +1))
fi
   
#
# Remove twice.
#

set +e
__remove_role_from_instance_profile "${PROFILE_NM}" "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing __remove_role_from_instance_profile twice.'
   counter=$((counter +1))
fi 

echo '__remove_role_from_instance_profile tests completed.'

###########################################
## TEST: delete_role
###########################################

__helper_clear_resources > /dev/null 2>&1 
exit_code=0;  policy_arn=''; instance_profiles_arn=''; role_id=''; policy_document='';

# Create a role with a permission policy attached.
__helper_create_role_policy_document
policy_document="${__RESULT}"

aws iam create-role --role-name "${ROLE_NM}" \
    --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 

# Create a permission policy and attach it to the role.
__helper_create_permission_policy "${POLICY_NM}" > /dev/null 2>&1
policy_arn="${__RESULT}"

aws iam attach-role-policy --role-name "${ROLE_NM}" --policy-arn "${policy_arn}"

# Create an instance profile and attach the role to it.
aws iam create-instance-profile --instance-profile-name "${PROFILE_NM}" > /dev/null 2>&1
aws iam  add-role-to-instance-profile --instance-profile-name "${PROFILE_NM}" \
    --role-name "${ROLE_NM}" 

#
# Missing argument.
#

set +e
delete_role > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_role with missing arguments.'
   counter=$((counter +1))
fi

#
# Not existing role.
#

set +e
delete_role 'XXX-assume-role' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing delete_role with not existing role.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
delete_role "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_role.'
   counter=$((counter +1))
fi

# Check the role has been deleted.
role_id="$(aws iam list-roles \
       --query "Roles[? RoleName=='${ROLE_NM}'].Arn" --output text)" 
       
if [[ -n "${role_id}" ]]
then  
   echo 'ERROR: testing delete_role, role not deleted.'
   counter=$((counter +1))   
fi

# Check the instance profile hasn't been deleted.
instance_profiles_arn="$(aws iam list-instance-profiles \
    --query "InstanceProfiles[? InstanceProfileName=='${PROFILE_NM}' ].Arn" --output text)"
   
if [[ -z "${instance_profiles_arn}" ]]
then
   echo 'ERROR: testing delete_role, the instance profile has been deleted.'
   counter=$((counter +1))   
fi 

# Check the policy hasn't been deleted.
policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='${POLICY_NM}' ].Arn" \
    --output text)"
   
if [[ -z "${policy_arn}" ]]
then
   echo 'ERROR: testing delete_role, the policy has been deleted.'
   counter=$((counter +1))   
fi 

#
# Delete twice.
#

set +e
delete_role "${ROLE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing delete_role.'
   counter=$((counter +1))
fi

echo 'delete_role tests completed.'

##############################################################
## TEST: check_permission_policy_exists
##############################################################

__helper_clear_resources > /dev/null 2>&1 
__helper_create_permission_policy "${POLICY_NM}" > /dev/null 2>&1
exit_code=0; policy_exists='';

#
# Missing argument.
#

set +e
check_permission_policy_exists > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_permission_policy_exists with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing policy.
#

set +e
check_permission_policy_exists 'xxxxx-53-policy' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_permission_policy_exists with not existing policy.'
   counter=$((counter +1))
fi

policy_exists="${__RESULT}"

if [[ 'false' != "${policy_exists}" ]]
then
   echo 'ERROR: testing check_permission_policy_exists with not existing policy.'
   counter=$((counter +1))
fi

#
# Empty policy name.
#

set +e
check_permission_policy_exists ' ' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_permission_policy_exists with empty policy name.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
check_permission_policy_exists "${POLICY_NM}" > /dev/null 2>&1
exit_code=$?
set -e

policy_exists="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_permission_policy_exists.'
   counter=$((counter +1))
fi

if [[ 'true' != "${policy_exists}" ]]
then
   echo 'ERROR: testing check_permission_policy_exists with valid policy.'
   counter=$((counter +1))
fi

echo 'check_permission_policy_exists tests completed.'

###########################################
## TEST: get_permission_policy_arn
###########################################

__helper_clear_resources > /dev/null 2>&1 
exit_code=0; policy_arn='';

#
# Missing argument.
#

set +e
get_permission_policy_arn > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_permission_policy_arn with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing policy.
#

get_permission_policy_arn 'xxxxx-53-policy' > /dev/null 2>&1
policy_arn="${__RESULT}"

# Empty string expected
if [[ -n "${policy_arn}" ]]
then
   echo 'ERROR: testing get_permission_policy_arn with not existing policy.'
   counter=$((counter +1))
fi

#
# Success.
#

__helper_create_permission_policy "${POLICY_NM}" > /dev/null 2>&1

set +e
get_permission_policy_arn "${POLICY_NM}" > /dev/null 2>&1
exit_code=$?
set -e

policy_arn="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_permission_policy_arn.'
   counter=$((counter +1))
fi

if [[ -z "${policy_arn}" ]]
then
   echo 'ERROR: testing get_permission_policy_arn with valid policy.'
   counter=$((counter +1))
fi

echo 'get_permission_policy_arn tests completed.' 

###########################################
## TEST: create_permission_policy
###########################################

__helper_clear_resources > /dev/null 2>&1
exit_code=0;

#
# Missing argument.
#

set +e
create_permission_policy "${POLICY_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_permission_policy with missing arguments.'
   counter=$((counter +1))
fi

#
# Create a policy successfully.
#

# Create the policy document.
__helper_create_permission_policy_document
policy_document="${__RESULT}"

set +e
create_permission_policy "${POLICY_NM}" 'Route 53 create and delete records policy.' \
    "${policy_document}" > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_permission_policy with missing arguments.'
   counter=$((counter +1))
else
   # Check the policy.
   policy_name="$(aws iam list-policies --query "Policies[? PolicyName=='${POLICY_NM}' ].PolicyName" \
       --output text)"   
   
   if [[ -z "${policy_name}" ]]
   then
      echo 'ERROR: testing create_permission_policy, policy not found.'
      counter=$((counter +1))
   fi
fi

#
# Create a policy twice.
#

# An error is expected.

set +e
create_permission_policy "${POLICY_NM}" 'Route 53 create and delete records policy.' \
    "${policy_document}" > /dev/null 2>&1 
exit_code=$?
set -e


# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing create_permission_policy twice.'
   counter=$((counter +1))
fi

######## TODO
######## Verify the policy grants work.
######## TODO

echo 'create_permission_policy tests completed.'

__helper_clear_resources > /dev/null 2>&1 

###########################################
## TEST: delete_permission_policy
###########################################

__helper_clear_resources > /dev/null 2>&1 
exit_code=0; policy_arn='';

#
# Missing argument.
#

set +e
delete_permission_policy > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_permission_policy with missing arguments.'
   counter=$((counter +1))
fi

__helper_create_permission_policy "${POLICY_NM}" > /dev/null 2>&1

#
# Delete a policy successfully.
#

set +e
delete_permission_policy "${POLICY_NM}" > /dev/null 2>&1        
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_permission_policy.'
   counter=$((counter +1))
fi

policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='${POLICY_NM}' ].Arn" --output text)"

# Empty string is expected.
if [[ -n "${policy_arn}" ]]
then
   echo 'ERROR: testing delete_permission_policy.'
   counter=$((counter +1))
fi

#
# Not existing policy.
#

set +e
delete_permission_policy 'xxxxx-53-policy' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing delete_permission_policy with not existing policy.'
   counter=$((counter +1))
fi

echo 'delete_permission_policy tests completed.'

__helper_clear_resources
   
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


