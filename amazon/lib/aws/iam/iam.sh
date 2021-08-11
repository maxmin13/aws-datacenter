#!/usr/bin/bash

set -o errexit
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
#  the server certificate ARN, returns the value in the __RESULT global variable. 
#===============================================================================
function get_server_certificate_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r crt_nm="${1}"

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
   
   declare -r crt_nm="${1}"
   declare -r crt_file="${2}"
   declare -r key_file="${3}"
   declare -r cert_dir="${4}"
   local chain_file=''
   local exit_code=0
   
   if [[ $# -gt 4 ]]; then
      chain_file="${5}"
   fi
 
   if [[ -z "${chain_file}" ]]
   then
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
   
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

   return "${exit_code}" 
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
   local exit_code=0

   aws iam delete-server-certificate --server-certificate-name "${crt_nm}" > /dev/null
   
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

   return "${exit_code}" 
}

#===============================================================================
# Returns a IAM users ARN.
#
# Globals:
#  None
# Arguments:
# +user_nm -- the user name.
# Returns:      
#  the user ARN in the __RESULT global variable.  
#===============================================================================
function get_user_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r user_nm="${1}"
   local user_arn=''

   user_arn="$(aws iam list-users --query "Users[? UserName=='${user_nm}'].Arn" --output text)"
       
   eval "__RESULT='${user_arn}'"      
   
   return 0
}

#===============================================================================
# Checks if a IAM user exists.
#
# Globals:
#  None
# Arguments:
# +name -- the user name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function check_user_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r user_nm="${1}"
   local user_arn=''
   local exists='false'

   user_arn="$(get_user_arn "${user_nm}")"
   
   if [[ -n "${user_arn}" ]]
   then
      exists='true'
   fi
       
   eval "__RESULT='${exists}'"      
   
   return 0
}

#===============================================================================
# Creates a new IAM user for your AWS account.
#
# Globals:
#  None
# Arguments:
# +user_nm -- the user name.
# Returns:      
#  none.  
#===============================================================================
function create_user()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r user_nm="${1}"
   local exit_code=0
   
   aws iam create-user --user-name "${user_nm}" > /dev/null  
   
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

   return "${exit_code}" 
}

#===============================================================================
# Deletes the specified IAM user. When you delete a user programmatically, you 
# must delete the items  attached to  the user.
#
# Globals:
#  None
# Arguments:
# +user_nm -- the user name.
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
   
   declare -r user_nm="${1}"
   local exit_code=0
   
    # Detach all policies from the user.
   policies="$(aws iam list-attached-user-policies --user-name "${user_nm}" --query "AttachedPolicies[].PolicyName" \
       --output text)"
       
   for policy_nm in ${policies}
   do
      __detach_managed_policy_from_user "${user_nm}" "${policy_nm}" > /dev/null
   done
 
   aws iam delete-user --user-name "${user_nm}" > /dev/null
   
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

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
#  the policy ARN, returns the value in the __RESULT global variable.  
#===============================================================================
function __get_managed_policy_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r policy_nm="${1}"
   local policy_arn=''

   policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='${policy_nm}' ].Arn" \
       --output text)"
   
   eval "__RESULT='${policy_arn}'"
   
   return 0
}

#===============================================================================
# Deletes the specified managed permissions policy.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function delete_managed_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r policy_nm="${1}"
   local policy_arn=''
   local exit_code=0

   __get_managed_policy_arn "${policy_nm}"
   policy_arn="${__RESULT}"

   if [[ -z "${policy_arn}" ]]
   then
      echo 'WARN: managed policy not found.'
      return 0
   fi
   
   aws iam delete-policy --policy-arn "${policy_arn}"
   
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

   return "${exit_code}"   
}

#===============================================================================
# Creates a new managed permissions policy for your AWS account.
#
# Globals:
#  None
# Arguments:
# +policy_nm       -- the policy name.
# +policy_desc     -- the policy description.
# +policy_document -- the JSON string that defines the IAM policy.
# Returns:      
#  none.    
#===============================================================================
function create_managed_policy()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r policy_nm="${1}"
   declare -r policy_desc="${2}"
   declare -r policy_document="${3}"
   local exit_code=0
       
   aws iam create-policy \
       --policy-name "${policy_nm}" \
       --description "${policy_desc}" \
       --policy-document "${policy_document}" \
       > /dev/null
    
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

   return "${exit_code}" 
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
function __build_route53_managed_policy_document()
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
            "route53:CreateTrafficPolicy",
            "sts:AssumeRole"
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
# Attaches the specified managed permissions policy to the specified IAM user.
#
# Globals:
#  None
# Arguments:
# +user_nm   -- the user name.
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function attach_managed_policy_to_user()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r user_nm="${1}"
   declare -r policy_nm="${2}"
   local exit_code=0

   __get_managed_policy_arn "${policy_nm}"
   policy_arn="${__RESULT}"

   aws iam attach-user-policy --user-name "${user_nm}" --policy-arn "${policy_arn}" > /dev/null
   
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

   return "${exit_code}" 
}

#===============================================================================
# Removes the specified managed permissions policy from the specified IAM user.
#
# Globals:
#  None
# Arguments:
# +user_nm   -- the user name.
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function __detach_managed_policy_from_user()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r user_nm="${1}"
   declare -r policy_nm="${2}"
   local policy_arn=''
   local exit_code=0

   __get_managed_policy_arn "${policy_nm}"
   policy_arn="${__RESULT}"
   
   aws iam detach-user-policy --user-name "${user_nm}" --policy-arn "${policy_arn}" > /dev/null
   
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

   return "${exit_code}" 
}

#===============================================================================
# 
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  A policy JSON document for accessing Route 53, returns the value in the 
# __RESULT variable.  
#===============================================================================
function __build_route53_trust_policy_document()
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
            "route53:CreateTrafficPolicy",
            "sts:AssumeRole"
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
# Creates a new role for your AWS account.
#
# Globals:
#  None
# Arguments:
# +role_nm              -- the role name.
# +role_policy_document -- the trust relationship policy document that grants 
#                          an entity permission to assume the role.
# +decription           -- the role description.
# Returns:      
#  none.  
#===============================================================================
function create_role()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r role_nm="${1}"
   declare -r role_policy_document="${2}"
   local exit_code=0

   aws iam create-role --role-name "${role_nm}" \
       --assume-role-policy-document "${role_policy_document}" \
       > /dev/null
   
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?

   return "${exit_code}" 
}

