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
# Deletes the specified server certificate on IAM by name, throws an error if 
# the certificate is not found.
#
# Globals:
#  None
# Arguments:
# +crt_nm     -- The Certificate name.
# Returns:      
#  None  
#===============================================================================
function delete_server_certificate()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local crt_nm="${1}"
 
   aws iam delete-server-certificate \
                --server-certificate-name "${crt_nm}"
  
   return 0
}

#===============================================================================
# Returns the Server Certificate ARN, or an empty string if the Certificate is
# not found.
#
# Globals:
#  None
# Arguments:
# +crt_nm     -- The Certificate name.
# Returns:      
#  The Server Certificate ARN.
#===============================================================================
function get_server_certificate_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local crt_nm="${1}"

   cert_arn="$(aws iam list-server-certificates \
                    --query "ServerCertificateMetadataList[?ServerCertificateName=='${crt_nm}'].Arn" \
                    --output text)" 
  
   echo "${cert_arn}"

   return 0
}
#===============================================================================
# Uploads a Server Certificate to IAM.
# Before you can upload a Certificate to IAM, you must make sure that the Certificate, Private Key, 
# and Certificate Chain are all PEM-encoded. You must also ensure that the Private Key is not protected
# by a passphrase. 
#
# Globals:
#  None
# Arguments:
# +crt_nm       -- The Certificate name.
# +crt_file     -- The contents of the Public Key Certificate in PEM-encoded
#                  format.
# +key_file     -- The contents of the Private Key in PEM-encoded format.
# +chain_file   -- The contents of the Certificate Chain (optional). This is typically a 
#                  concatenation of the PEM-encoded public key certificates 
#                  of the chain.
# +cert_dir     -- The directory where the certificates are stored.
# Returns:      
#  None
#===============================================================================
function upload_server_certificate()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local crt_nm="${1}"
   local crt_file="${2}"
   local key_file="${3}"
   local cert_dir="${4}"
   local chain_file=''
   
   if [[ $# -gt 4 ]]; then
   	chain_file="${5}"
   fi
   
   local cert_arn
 
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

