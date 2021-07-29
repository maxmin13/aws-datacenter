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
#  the server certificate ARN.
#===============================================================================
function get_server_certificate_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local crt_nm="${1}"

   cert_arn="$(aws iam list-server-certificates \
       --query "ServerCertificateMetadataList[?ServerCertificateName=='${crt_nm}'].Arn" \
       --output text)" 
  
   echo "${cert_arn}"

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
#  None
#===============================================================================
function upload_server_certificate()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
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
#  None  
#===============================================================================
function delete_server_certificate()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local crt_nm="${1}"
   local exit_code=0
   
   set +e
   aws iam delete-server-certificate --server-certificate-name "${crt_nm}" > /dev/null 2>&1
   exit_code=$?
   set -e
   
   return "${exit_code}"
}

#===============================================================================
# 
#
# Globals:
#  None
# Arguments:
# +name -- the user name.
# Returns:      
#  None  
#===============================================================================
function create_user()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local name="${1}"
   
   aws iam create-user --user-name "${name}" 
   
   return 0
}

#===============================================================================
# Deletes the specified managed policy.
#
# Globals:
#  None
# Arguments:
# +name -- the policy name.
# Returns:      
#  None.  
#===============================================================================
function delete_route53_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local name="${1}"
   local arn=''

   arn="$(aws iam list-policies --query "Policies[? PolicyName=='${name}' ].Arn" --output text)"

   if [[ -n "${arn}" ]]
   then
      echo 'deleting in delete_route_policy'
      aws iam delete-policy --policy-arn "${arn}"
   else 
      echo 'not found in delete_route_policy'
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
# +name -- the policy name.
# Returns:      
#  the policy ARN or a blanc string if there is an error.  
#===============================================================================
function create_route53_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local name="${1}"
   local arn=''
   local description='Create/delete Route 53 records.'
   local policy_document=''

   policy_document="$(__build_route53_policy_document)"       
        
   set +e        
   arn="$(aws iam create-policy \
          --policy-name "${name}" \
          --description "${description}" \
          --policy-document "${policy_document}" \
          --query "Policy.Arn" \
          --output text 2>/dev/null)"    
   set -e
   
   echo "${arn}"    
   
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
#  A policy JSON document for accessing Route 53.  
#===============================================================================
function __build_route53_policy_document()
{
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
    
   echo "${policy_document}"
   
   return 0
}

