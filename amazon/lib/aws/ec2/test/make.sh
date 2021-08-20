#!/usr/bin/bash

set +o errexit
set +o pipefail
set +o nounset
set +o xtrace
   
counter=0

##
## Functions used to handle test data.
##



function __helper_clear_resources 
{
   # Clear the global __RESULT variable.
   __RESULT=''


        
   return 0
}

##
##
##
echo 'Starting ec2.sh script tests ...'
echo
##
##
##

#######################################################
## TEST: check_instance_has_instance_profile_associated
#######################################################

__helper_clear_resources > /dev/null 2>&1 

### TODO

echo 'check_instance_has_instance_profile_associated tests completed.'



###########################################
## TEST: get_instance_id
###########################################

__helper_clear_resources > /dev/null 2>&1 

### TODO

echo 'get_instance_id tests completed.'

__helper_clear_resources > /dev/null 2>&1 
    
###########################################
## TEST: get_instance_profile_id
###########################################

__helper_clear_resources > /dev/null 2>&1 

### TODO

echo 'get_instance_profile_id tests completed.'

############################################
## TEST: associate_instance_profile_to_instance
############################################

__helper_clear_resources > /dev/null 2>&1

### TODO

echo 'associate_instance_profile_to_instance tests completed.'



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


