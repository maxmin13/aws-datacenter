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
#  The Account number.  
#===============================================================================
function get_account_number()
{
   local aws_account="$(aws sts get-caller-identity \
                          --query 'Account' \
                          --output text)"
                        
   echo "${aws_account}"
 
   return 0
}
