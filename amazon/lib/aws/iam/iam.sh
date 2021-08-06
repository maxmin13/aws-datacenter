#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: iam.sh
#   DESCRIPTION: The script contains functions that use AWS client to make 
#                calls to AWS Identity and Access Management (IAM).
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Returns the Server Certificate ARN, or an empty string if the Certificate is
# not found.
#
# Globals:
#  None
# Arguments:
# +crt_nm -- the certificate name.
# Returns:      
#  the server certificate ARN, returns the value in the __RESULT variable. 
#===============================================================================
function get_server_certificate_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local crt_nm="${1}"

   cert_arn="$(aws iam list-server-certificates \
       --query "ServerCertificateMetadataList[?ServerCertificateName=='${crt_nm}'].Arn" \
       --output text)" 
  
   eval "__RESULT='${cert_arn}'"

   return 0
}
#===============================================================================
# Uploads a server certificate to IAM.
# Before you can upload a certificate to IAM, you must make sure that the 
# certificate, private-key and certificate chain are all PEM-encoded. 
# You must also ensure that the private-key is not protected by a passphrase. 
#
# Globals:
#  None
# Arguments:
# +crt_nm     -- the certificate name.
# +crt_file   -- the contents of the public-key certificate in PEM-encoded 
#                format.
# +key_file   -- the contents of the private-key in PEM-encoded format.
# +chain_file -- the contents of the certificate chain (optional). This is  
#                typically a concatenation of the PEM-encoded public key  
#                certificates of the chain.
# +cert_dir   -- the directory where the certificates are stored.
# Returns:      
#  none.
#===============================================================================
function upload_server_certificate()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local crt_nm="${1}"
   local crt_file="${2}"
   local key_file="${3}"
   local cert_dir="${4}"
   local chain_file=''
   
   if [[ $# -gt 4 ]]; then
      chain_file="${5}"
   fi
 
   if [[ -z "${chain_file}" ]]; then
      aws iam upload-server-certificate \
          --server-certificate-name "${crt_nm}" \
          --certificate-body file://"${cert_dir}/${crt_file}" \
          --private-key file://"${cert_dir}/${key_file}" > /dev/null
   else
      aws iam upload-server-certificate \
          --server-certificate-name "${crt_nm}" \
          --certificate-body file://"${cert_dir}/${crt_file}" \
          --private-key file://"${cert_dir}/${key_file}" \
          --certificate-chain file://"${cert_dir}/${chain_file}" > /dev/null
   fi
   
   echo 'Certificate uploaded.'
  
   return 0
}

#===============================================================================
# Deletes the specified server certificate on IAM by name, throws an error if 
# the certificate is not found.
#
# Globals:
#  None
# Arguments:
# +crt_nm -- the certificate name.
# Returns:      
#  none.  
#===============================================================================
function delete_server_certificate()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r crt_nm="${1}"
   declare -i exit_code=0
   
   set +e
   aws iam delete-server-certificate --server-certificate-name "${crt_nm}" > /dev/null 2>&1
   exit_code=$?
   set -e
   
   if [[ 0 -eq "${exit_code}" ]]
   then 
     echo 'Certificate deleted.'
   else
     echo 'WARN: certificate not found.'
   fi
   
   return "${exit_code}"
}

#===============================================================================
# Creates a new IAM user for your AWS account.
#
# Globals:
#  None
# Arguments:
# +name -- the user name.
# Returns:      
#  the user's ARN, returns the value in the __RESULT variable.  
#===============================================================================
function create_user()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r name="${1}"
   local user_arn=''

   user_arn="$(aws iam create-user --user-name "${name}" \
       --query "User.Arn" \
       --output text)"
       
   eval "__RESULT='${user_arn}'"      
   
   return 0
}

#===============================================================================
# Deletes the specified IAM user. When you delete a user programmatically, you 
# must delete the items  attached to  the user.
#
# Globals:
#  None
# Arguments:
# +name -- the user name.
# Returns:      
#  none.  
#===============================================================================
function delete_user()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r name="${1}"
   declare -i exit_code=0
 
   set +e
   aws iam delete-user --user-name "${name}" > /dev/null
   exit_code=$?
   set -e
   
   if [[ 0 -eq "${exit_code}" ]]
   then 
     echo 'User deleted.'
   else
     echo 'WARN: error deleting user.'
   fi   
   
   return "${exit_code}"   
}

#===============================================================================
# Adds the specified user to the specified group.
#
# Globals:
#  None
# Arguments:
# +user_nm  -- the user name.
# +group_nm -- the group name.
# Returns:      
#  None.  
#===============================================================================
function add_user_to_group()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r user_nm="${1}"
   declare -r group_nm="${2}"

   aws iam add-user-to-group --user-name "${user_nm}" --group-name "${group_nm}" 
   
   return 0
}

#===============================================================================
# Removes the specified user from the specified group.
#
# Globals:
#  None
# Arguments:
# +user_nm  -- the user's name.
# +group_nm -- the group's name.
# Returns:      
#  none.  
#===============================================================================
function __remove_user_from_group()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r group_nm="${1}"
   declare -r user_nm="${2}"
   
   aws iam remove-user-from-group --user-name "${user_nm}" --group-name "${group_nm}" 
   
   return 0
}

#===============================================================================
# Creates a new IAM group for your AWS account.
#
# Globals:
#  None
# Arguments:
# +group_nm -- the group name.
# Returns:      
#  the group's ARN, returns the value in the __RESULT variable.  .  
#===============================================================================
function create_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r group_nm="${1}"
   local group_arn=''

   group_arn="$(aws iam create-group --group-name "${group_nm}" \
       --query "Group.Arn" \
       --output text)"  
       
   echo 'Group created.'    
       
   eval "__RESULT='${group_arn}'" 
   
   return 0
}

#===============================================================================
# Deletes  the  specified IAM group. The users from the group and the embedded
# policies are removed before deleting the group. 
#
# Globals:
#  None
# Arguments:
# +group_nm -- the group name.
# Returns:      
#  none.  
#===============================================================================
function delete_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r group_nm="${1}"
   local group_id=''
   declare -i exit_code=0
   local users=''
   local user_nm=''
   local policies=''
   local policy_nm=''
   
   group_id="$(aws iam list-groups --query "Groups[? GroupName=="${group_nm}" ].GroupId" --output text)"
   
   if test 0 -ne "${exit_code}"
   then
      echo 'WARN: group not found.'
      return 0
   fi
   
   # Remove all users from the user group.
   
   users="$(aws iam get-group --group-name "${group_nm}" --query "Users[].UserName" --output text)"
   
   for user_nm in ${users}
   do
      __remove_user_from_group "${group_nm}" "${user_nm}"
      
      echo "${user_nm} user removed from group."
   done
   
   # Detach all policies from the user group.
   policies="$(aws iam list-attached-group-policies --group-name "techies" --query "AttachedPolicies[].PolicyName" \
       --output text)"
   
   for policy_nm in ${policies}
   do
      __detach_policy_from_group "${group_nm}" "${policy_nm}"
      
      echo "${policy_nm} detached from group."
   done
   
   set +e
   aws iam delete-group --group-name "${group_nm}" ##### > /dev/null 2>&1
   exit_code=$?
   set -e
   
   if [[ 0 -eq "${exit_code}" ]]
   then 
     echo 'Group deleted.'
   else
     echo 'WARN: error deleting group.'
   fi
   
   return "${exit_code}"   
}

#===============================================================================
# Returns the policy ARN.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# Returns:      
#  the policy ARN, returns the value in the __RESULT variable.  
#===============================================================================
function __get_policy_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r policy_nm="${1}"
   local arn=''

   arn="$(aws iam list-policies --query "Policies[? PolicyName=='${policy_nm}' ].Arn" \
       --output text)"
   
   eval "__RESULT='${arn}'"
   
   return 0
}

#===============================================================================
# Deletes the specified managed policy.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function delete_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r policy_nm="${1}"
   local policy_arn=''

   __get_policy_arn "${policy_nm}"
   policy_arn="${__RESULT}"

   if [[ -n "${policy_arn}" ]]
   then
      aws iam delete-policy --policy-arn "${policy_arn}"
   else 
      echo 'WARN: policy not found.'
   fi
       
   return 0
}

#===============================================================================
# Creates a new managed policy for your AWS account that allows the users to 
# create and delete records in Route 53.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# Returns:      
#  the policy ID or a blanc string if there is an error, returns the value in  
# the __RESULT variable.    
#===============================================================================
function create_route53_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r policy_nm="${1}"
   local id=''
   declare -r description='Create/delete Route 53 records.'
   local policy_document=''

   __build_route53_policy_document
   policy_document="${__RESULT}"      
        
   set +e        
   id="$(aws iam create-policy \
       --policy-name "${policy_nm}" \
       --description "${description}" \
       --policy-document "${policy_document}" \
       --query "Policy.PolicyId" \
       --output text 2>/dev/null)"    
   set -e
   
   eval "__RESULT='${id}'"   
   
   return 0
}

#===============================================================================
# Create a policy document that allows the user to create and delete records in
# Route 53.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  A policy JSON document for accessing Route 53, returns the value in the 
# __RESULT variable.  
#===============================================================================
function __build_route53_policy_document()
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

#===============================================================================
# Attaches the specified managed policy to the specified IAM group.
#
# Globals:
#  None
# Arguments:
# +group_nm  -- the group name.
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function attach_policy_to_group()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r group_nm="${1}"
   declare -r policy_nm="${2}"
   local policy_arn=''

   policy_arn="$(__get_policy_arn "${policy_nm}")"

   aws iam attach-group-policy --group-name "${group_nm}" --policy-arn "${policy_arn}"   
   
   return 0
}

#===============================================================================
# Removes the specified managed policy from the specified IAM group.
#
# Globals:
#  None
# Arguments:
# +group_nm  -- the group name.
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function __detach_policy_from_group()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r group_nm="${1}"
   declare -r policy_nm="${2}"
   local policy_arn=''

   __get_policy_arn "${policy_nm}"
   policy_arn="${__RESULT}"
   
   if [[ -n "${policy_arn}" ]]
   then
      aws iam detach-group-policy --group-name "${group_nm}" --policy-arn "${policy_arn}"
         
      echo 'Policy detached from group.'
   else
      echo 'WARN: policy not found.'
   fi

   return 0
}



