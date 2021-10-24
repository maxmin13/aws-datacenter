#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: sts.sh
#   DESCRIPTION: The script contains functions that use AWS client to make 
#                calls to AWS Security Token Service (AWS STS).
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Returns the account number of the IAM user or role whose credentials are used
# to call the operation.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  The Account number in the global __RESULT variable.  
#===============================================================================
function get_account_number()
{
   __RESULT=''
   local exit_code=0
   local aws_account=''
   
   aws_account="$(aws sts get-caller-identity \
                          --query 'Account' \
                          --output text)"           
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving account number.'
      return "${exit_code}"
   fi
                        
   __RESULT="${aws_account}"
 
   return "${exit_code}"
}

#===============================================================================
# Returns  a set of temporary credentials for an AWS account or IAM user.
# The credentials consist of an access key ID and a secret access key.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  a string containing access key ID and secret access key in the global 
#  __RESULT variable. 
#===============================================================================
function get_temporary_access_keys_pair()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local exit_code=0
   declare -r duration="${1}"
   local key_pair=''
   
   key_pair="$(aws sts get-session-token --duration-seconds "${duration}" \
       --query "Credentials.[AccessKeyId, SecretAccessKey]" --output text)"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving session token.'
      return "${exit_code}"
   fi
                        
   __RESULT="${key_pair}"
 
   return "${exit_code}"
}

