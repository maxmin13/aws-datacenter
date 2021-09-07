#!/usr/bin/bash

set +o errexit
set +o pipefail
set +o nounset
set +o xtrace
   
counter=0; __RESULT='';
ROLE_NM='EC2-test-assume-role'
PROFILE_NM='EC2-test-instance-profile'
INSTANCE_NM='EC2-test-instance1'

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

function __helper_clear_instance()
{ 
   # Clear the global __RESULT variable.
   __RESULT=''

   #
   # EC2 instance.
   #
   
   instance_id="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${INSTANCE_NM}" \
       --query 'Reservations[*].Instances[*].InstanceId' \
       --output text)"
       
   if [[ -n "${instance_id}" ]] 
   then
      aws ec2 terminate-instances --instance-ids "${instance_id}" > /dev/null 2>&1
      
      echo 'Test instance deleted.'
   fi 
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
      instance_profiles="$(aws iam list-instance-profiles-for-role --role-name "${ROLE_NM}" \
          --query "InstanceProfiles[].InstanceProfileName" --output text)"
   
      for profile_nm in ${instance_profiles}
      do
         aws iam remove-role-from-instance-profile --instance-profile-name "${profile_nm}" \
             --role-name "${ROLE_NM}"
             
         echo 'Test role removed from instance profile.'      
      done       
      
      aws iam delete-role --role-name "${ROLE_NM}" > /dev/null
   
      echo 'Test role deleted.'
   fi
      
   #
   # Instance profile.
   # 
   
   instance_id="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${INSTANCE_NM}" \
       --query 'Reservations[*].Instances[*].InstanceId' \
       --output text)"
    
   if [[ -n "${instance_id}" ]]
   then
      # Check if the instance profile is associated with the instance.
      association_id="$(aws ec2 describe-iam-instance-profile-associations \
         --query "IamInstanceProfileAssociations[? InstanceId == '${instance_id}'].AssociationId"  \
         --output text)"
       
      if [[ -n "${association_id}" ]]
      then
         aws ec2 disassociate-iam-instance-profile --association-id "${association_id}"
        
         echo 'Test instance profile association deleted.'
      fi   
   fi
   
   profile_id="$(aws iam list-instance-profiles \
       --query "InstanceProfiles[? InstanceProfileName=='${PROFILE_NM}' ].InstanceProfileId" --output text)"
     
   if [[ -n "${profile_id}" ]]
   then      
      aws iam delete-instance-profile --instance-profile-name "${PROFILE_NM}"
      
      echo 'Test instance profile deleted'
   fi   
   
   return 0   
}

trap "__helper_clear_instance; __helper_clear_resources" EXIT

__helper_clear_resources > /dev/null 2>&1

##
## Create and EC2 instance and an instance profile.
##

echo 'Starting EC2 test instance ...'

instance_id="$(aws ec2 describe-instances \
    --filters Name=tag-key,Values=Name \
    --filters Name=tag-value,Values="${INSTANCE_NM}" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)"   
   
if [[ -n "${instance_id}" ]]
then
   instance_state="$(get_instance_state "${INSTANCE_NM}")"
   
   if [[ 'running' == "${instance_state}" || \
         'stopped' == "${instance_state}" || \
         'pending' == "${instance_state}" ]] 
   then
      echo "WARN: EC2 test instance already created (${instance_state})."
   else
      echo "ERROR: EC2 test instance already created (${instance_state})."
      exit 1
   fi
else
   echo "Creating EC2 test instance ..."

   instance_id="$(aws ec2 run-instances \
       --image-id "${AWS_BASE_IMG_ID}" \
       --block-device-mapping 'DeviceName=/dev/xvda,Ebs={DeleteOnTermination=true,VolumeSize=10}' \
       --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value='${INSTANCE_NM}'}]" \
       --output text \
       --query 'Instances[*].InstanceId')"

   echo "EC2 test instance created."
fi

# Create a role.
__helper_create_role_policy_document
policy_document="${__RESULT}"
aws iam create-role --role-name "${ROLE_NM}" \
    --assume-role-policy-document "${policy_document}" > /dev/null 2>&1 

# Create an instance profile and attach the role to it.
profile_id="$(aws iam create-instance-profile --instance-profile-name "${PROFILE_NM}" \
    --query "InstanceProfile.InstanceProfileId" --output text)"
aws iam add-role-to-instance-profile --instance-profile-name "${PROFILE_NM}" \
    --role-name "${ROLE_NM}" > /dev/null 2>&1
    
echo 'Test instance profile created.'    
       
##
##
##
echo 'Starting ec2.sh script tests ...'
echo
##
##
##

###########################################
## TEST: get_instance_id
###########################################

exit_code=0; instance_id='';

#
# Missing argument.
#

set +e
get_instance_id > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_instance_id with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing instance.
#  

set +e
get_instance_id 'XXX-instance' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_instance_id with not existing instance.'
   counter=$((counter +1))
fi

instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   echo 'ERROR: testing get_instance_id with not existing instance.'
   counter=$((counter +1))
fi

#
# Success.
#

instance_id=''

set +e
get_instance_id "${INSTANCE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

instance_id="${__RESULT}"

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_instance_id.'
   counter=$((counter +1))
fi

if [[ -z "${instance_id}" ]]
then
   echo 'ERROR: testing get_instance_id with existing instance.'
   counter=$((counter +1))
fi

echo 'get_instance_id tests completed.'

####################################################
## TEST: __get_association_id
####################################################

association_id=''; exit_code=0; policy_document=''; association_state='';
    
#
# Missing argument.
#

set +e
__get_association_id "${INSTANCE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing __get_association_id with missing arguments.'
   counter=$((counter +1))
fi 

#
# Instance profile not associated.
#

set +e
__get_association_id "${INSTANCE_NM}" "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing __get_association_id with no profile associated.'
   counter=$((counter +1))
fi 

association_id="${__RESULT}"

# Blanc value expected.
if [[ -n "${association_id}" ]]
then
   echo 'ERROR: testing __get_association_id with no profile associated, blanc value expected.'
   counter=$((counter +1))
fi 

echo '__get_association_id tests with profile not associated completed.'

#######################################################
## TEST: check_instance_has_instance_profile_associated
#######################################################

association_id=''; exit_code=0; policy_document=''; is_profile_associated='';

#
# Missing argument.
#

set +e
check_instance_has_instance_profile_associated "${INSTANCE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_has_instance_profile_associated with missing arguments.'
   counter=$((counter +1))
fi 

#
# Instance profile not associated.
#

check_instance_has_instance_profile_associated "${INSTANCE_NM}" "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_has_instance_profile_associated.'
   counter=$((counter +1))
fi 

is_profile_associated="${__RESULT}"

if [[ 'false' != "${is_profile_associated}" ]]
then
   echo 'ERROR: testing check_instance_has_instance_profile_associated with profile not associated to instance.'
   counter=$((counter +1))
fi  

echo 'check_instance_has_instance_profile_associated tests with profile not associated completed.'

###############################################
## TEST: associate_instance_profile_to_instance
###############################################

association_id=''; exit_code=0; policy_document=''; profile_id='';
    
#
# Missing argument.
#

set +e
associate_instance_profile_to_instance "${INSTANCE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing associate_instance_profile_to_instance with missing arguments.'
   counter=$((counter +1))
fi     

#
# Instance profile not associated.
#

exit_code=0

# Associate the instance profile to the running instance (give IAM some time).       
associate_instance_profile_to_instance "${INSTANCE_NM}" "${PROFILE_NM}" > /dev/null 2>&1 || 
   {
      # Wait for IAM and try again.
      __wait 25
      set +e
      associate_instance_profile_to_instance "${INSTANCE_NM}" "${PROFILE_NM}" > /dev/null 2>&1 
      exit_code=$?
      set -e 
   } 
    
# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing associate_instance_profile_to_instance, no error expected.'
   counter=$((counter +1))
fi

profile_id="$(aws iam list-instance-profiles \
    --query "InstanceProfiles[?InstanceProfileName=='${PROFILE_NM}'].InstanceProfileId" \
    --output text)"

# Check the association.
association_id="$(aws ec2 describe-iam-instance-profile-associations \
       --query "IamInstanceProfileAssociations[? InstanceId == '${instance_id}' && IamInstanceProfile.Id == '${profile_id}'].AssociationId"  \
       --output text)" ||
    {
        # Wait for IAM and try again.
        __wait 25
        association_id="$(aws ec2 describe-iam-instance-profile-associations \
           --query "IamInstanceProfileAssociations[? InstanceId == '${instance_id}' && IamInstanceProfile.Id == '${profile_id}'].AssociationId"  \
           --output text)"
    }

if [[ -z "${association_id}" ]]
then
   echo 'ERROR: testing associate_instance_profile_to_instance.'
   counter=$((counter +1))
fi

#
# Associate twice.
#

set +e
associate_instance_profile_to_instance "${INSTANCE_NM}" "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing associate_instance_profile_to_instance twice.'
   counter=$((counter +1))
fi

echo 'associate_instance_profile_to_instance tests with profile not associated completed.'

####################################################
## TEST: __get_association_id
####################################################

association_id=''; exit_code=0; policy_document=''; association_state='';

#
# Instance profile associated.
#

set +e
__get_association_id "${INSTANCE_NM}" "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing __get_association_id, no error is expected.'
   counter=$((counter +1))
fi 

association_id="${__RESULT}"

if [[ -z "${association_id}" ]]
then
   echo 'ERROR: testing __get_association_id with profile associated to instance.'
   counter=$((counter +1))
fi

echo '__get_association_id tests with profile associated completed.'

#######################################################
## TEST: check_instance_has_instance_profile_associated
#######################################################

association_id=''; exit_code=0; policy_document=''; is_profile_associated='';

#
# Instance profile associated.
#

check_instance_has_instance_profile_associated "${INSTANCE_NM}" "${PROFILE_NM}"
exit_code=$?

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing check_instance_has_instance_profile_associated.'
   counter=$((counter +1))
fi 

is_profile_associated="${__RESULT}"

if [[ 'true' != "${is_profile_associated}" ]]
then
   echo 'ERROR: testing check_instance_has_instance_profile_associated with profile associated to instance.'
   counter=$((counter +1))
fi 

echo 'check_instance_has_instance_profile_associated tests with profile associated completed.'

####################################################
## TEST: disassociate_instance_profile_from_instance
####################################################

association_id=''; exit_code=0; policy_document='';  

#
# Missing argument.
#

set +e
disassociate_instance_profile_from_instance "${INSTANCE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing disassociate_instance_profile_from_instance with missing arguments.'
   counter=$((counter +1))
fi 

#
# Instance profile associated.
#

set +e
disassociate_instance_profile_from_instance "${INSTANCE_NM}" "${PROFILE_NM}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing disassociate_instance_profile_from_instance with profile associated.'
   counter=$((counter +1))
fi 

# Check the state of the profile.
profile_st=$(aws ec2 describe-iam-instance-profile-associations \
    --query "IamInstanceProfileAssociations[? InstanceId == '${instance_id}' && IamInstanceProfile.Id == '${profile_id}'].AssociationId"  \
    --output text)
    
if [[ -z "${profile_st}" ]]
then
   echo 'ERROR: testing disassociate_instance_profile_from_instance with profile associated, wrong instance profile state.'
   counter=$((counter +1))
fi

echo 'disassociate_instance_profile_from_instance tests with profile associated completed.'

##############################################
# Count the errors.
##############################################

echo

if [[ "${counter}" -gt 0 ]]
then
   echo "ec2.sh script test completed with ${counter} errors."
else
   echo 'ec2.sh script test successfully completed.'
fi

echo

__helper_clear_instance 
__helper_clear_resources

echo


