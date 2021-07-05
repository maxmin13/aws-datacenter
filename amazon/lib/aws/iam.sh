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
          --private-key file://"${cert_dir}/${key_file}" >> /dev/null
   else
      aws iam upload-server-certificate \
          --server-certificate-name "${crt_nm}" \
          --certificate-body file://"${cert_dir}/${crt_file}" \
          --private-key file://"${cert_dir}/${key_file}" \
          --certificate-chain file://"${cert_dir}/${chain_file}" >> /dev/null
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
