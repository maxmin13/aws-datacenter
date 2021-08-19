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

   __RESULT=''
   declare -r crt_nm="${1}"
   local exit_code=0

   cert_arn="$(aws iam list-server-certificates \
       --query "ServerCertificateMetadataList[?ServerCertificateName=='${crt_nm}'].Arn" \
       --output text)" 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting server certificate ARN.' 
      return "${exit_code}"
   fi 
   
   if [[ -z "${cert_arn}" ]] 
   then
      echo 'Certificate not found.'
   fi 
      
   __RESULT="${cert_arn}"
   
   return "${exit_code}"
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
   
   __RESULT=''
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
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: uploading server certificate.' 
   fi   
   
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

   __RESULT=''
   declare -r crt_nm="${1}"
   local exit_code=0

   aws iam delete-server-certificate --server-certificate-name "${crt_nm}" > /dev/null
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting server certificate.' 
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
#  the policy ARN, returns the value in the __RESULT global variable.  
#===============================================================================
function get_permission_policy_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r policy_nm="${1}"
   local policy_arn=''
   local exit_code=0

   policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='${policy_nm}' ].Arn" \
       --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting permission policy ARN.' 
      return "${exit_code}"
   fi 
   
   if [[ -z "${policy_arn}" ]] 
   then
      echo 'Policy not found.'
   fi

   __RESULT="${policy_arn}"
   
   return "${exit_code}"
}

#===============================================================================
# Checks if a IAM managed policy exists.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function check_permission_policy_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   declare -r policy_nm="${1}"
   local policy_arn=''
   local exists='false'
   local exit_code=0

   get_permission_policy_arn "${policy_nm}"
   exit_code=$?
   policy_arn="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi 
    
   if [[ -n "${policy_arn}" ]]
   then
      exists='true'
   fi
       
   __RESULT="${exists}"      
   
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
function delete_permission_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r policy_nm="${1}"
   local policy_arn=''
   local policy_exists='false'
   local exit_code=0
   
   check_permission_policy_exists "${policy_nm}"
   exit_code=$?
   policy_exists="${__RESULT}"
   __RESULT=''

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${policy_exists}" ]]
   then
      echo 'ERROR: permission policy not found.' 
      return 1
   fi
    
   get_permission_policy_arn "${policy_nm}"
   exit_code=$?
   policy_arn="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy ARN.' 
      return "${exit_code}"
   fi
   
   aws iam delete-policy --policy-arn "${policy_arn}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting permission policy.' 
   fi

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
function create_permission_policy()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r policy_nm="${1}"
   declare -r policy_desc="${2}"
   declare -r policy_document="${3}"
   local exit_code=0
       
   aws iam create-policy \
       --policy-name "${policy_nm}" \
       --description "${policy_desc}" \
       --policy-document "${policy_document}" \
       > /dev/null
    
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating permission policy.' 
   fi

   return "${exit_code}" 
}

#===============================================================================
# Create a policy document that allows to create and delete records in Route 53.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  A policy JSON document for accessing Route 53, returns the value in the 
# __RESULT global variable.  
#===============================================================================
function build_route53_permission_policy_document()
{
   __RESULT=''
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
    
   __RESULT="${policy_document}"
   
   return 0
}

#===============================================================================
# Attaches the specified managed permissions policy to the specified IAM role.
#
# Globals:
#  None
# Arguments:
# +role_nm   -- the role name.
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function attach_permission_policy_to_role()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r role_nm="${1}"
   declare -r policy_nm="${2}"
   local policy_exists='false'
   local exit_code=0

   check_permission_policy_exists "${policy_nm}"
   exit_code=$?
   policy_exists="${__RESULT}"
   __RESULT=''

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${policy_exists}" ]]
   then
      echo 'ERROR: permission policy not found.' 
      return 1
   fi
    
   get_permission_policy_arn "${policy_nm}"
   exit_code=$?
   policy_arn="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy ARN.' 
      return "${exit_code}"
   fi

   aws iam attach-role-policy --role-name "${role_nm}" --policy-arn "${policy_arn}" > /dev/null
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: attaching permission policy to role.' 
   fi 

   return "${exit_code}" 
}

#===============================================================================
# Checks if the specified IAM role has a managed permission policy attached.
#
# Globals:
#  None
# Arguments:
# +role_nm   -- the role name.
# +policy_nm -- the policy name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function check_role_has_permission_policy_attached()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r role_nm="${1}"
   declare -r policy_nm="${2}"
   local attached='false'
   local role_exists='false'
   local policy_exists='false'
   local exit_code=0
   local policy_arn=''
   
   check_role_exists "${role_nm}"
   exit_code=$?
   role_exists="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving role.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${role_exists}" ]]
   then
      echo 'ERROR: role not found.' 
      return 1
   fi
   
   check_permission_policy_exists "${policy_nm}"
   exit_code=$?
   policy_exists="${__RESULT}"
   __RESULT=''

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${policy_exists}" ]]
   then
      echo 'ERROR: permission policy not found.' 
      return 1
   fi

   policy_arn="$(aws iam list-attached-role-policies --role-name "${role_nm}" \
       --query "AttachedPolicies[? PolicyName=='${policy_nm}'].PolicyArn" --output text)"
   exit_code=$?
 
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   else
      if [[ -n "${policy_arn}" ]]
      then
         attached='true' 
      fi
   fi 
       
   __RESULT="${attached}"

   return "${exit_code}" 
}

#===============================================================================
# Removes the specified permissions policy from the specified IAM role.
#
# Globals:
#  None
# Arguments:
# +role_nm   -- the role name.
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#=================$==============================================================
function __detach_permission_policy_from_role()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r role_nm="${1}"
   declare -r policy_nm="${2}"
   local policy_arn=''
   local role_exists='false'
   local policy_exists='false'
   local exit_code=0
   
   check_role_exists "${role_nm}"
   exit_code=$?
   role_exists="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving role.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${role_exists}" ]]
   then
      echo 'ERROR: role not found.' 
      return 1
   fi
   
   check_permission_policy_exists "${policy_nm}"
   exit_code=$?
   policy_exists="${__RESULT}"
   __RESULT=''

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${policy_exists}" ]]
   then
      echo 'ERROR: permission policy not found.' 
      return 1
   fi
   
   get_permission_policy_arn "${policy_nm}"
   exit_code=$?
   policy_arn="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy ARN.' 
      return "${exit_code}"
   fi

   aws iam detach-role-policy --role-name "${role_nm}" --policy-arn "${policy_arn}" > /dev/null
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: detaching permission policy from role.' 
   fi

   return "${exit_code}" 
}

#===============================================================================
# Builds the trust policy that allows EC2 instances to assume a role. 
# Trust policies define which entities can assume the role. 
# You can associate only one trust policy with a role.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  The policy JSON document in the __RESULT global variable.  
#===============================================================================
function build_assume_role_policy_document_for_ec2_entities()
{
   __RESULT=''
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

#===============================================================================
# Creates a new role for your AWS account.
#
# Globals:
#  None
# Arguments:
# +role_nm              -- the role name.
# +role_desc            -- the role description.
# +role_policy_document -- the trust policy that is associated with this role. 
# +decription           -- the role description.
# Returns:      
#  none.  
#===============================================================================
function create_role()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r role_nm="${1}"
   declare -r role_desc="${2}"
   declare -r role_policy_document="${3}"
   local exit_code=0

   aws iam create-role --role-name "${role_nm}" --description "${role_desc}" \
       --assume-role-policy-document "${role_policy_document}" \
       > /dev/null

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating role.' 
   fi

   return "${exit_code}" 
}

#===============================================================================
# Deletes the specified role, detaches instance profiles and permission policies
# from it.
#
# Globals:
#  None
# Arguments:
# +role_nm -- the role name.
# Returns:      
#  none.  
#===============================================================================
function delete_role()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   declare -r role_nm="${1}"
   local role_exists='false'
   local exit_code=0
   
   check_role_exists "${role_nm}"
   exit_code=$?
   role_exists="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the role.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${role_exists}" ]]
   then
      echo 'ERROR: role not found.' 
      return 1
   fi
   
   # List the instance profiles attached to the role.
   instance_profiles="$(aws iam list-instance-profiles-for-role --role-name "${role_nm}" \
       --query "InstanceProfiles[].InstanceProfileName" --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance profiles to which the role is attached.' 
      return "${exit_code}"
   fi
   
   # List the permission policies attached to the role.
   policies="$(aws iam list-attached-role-policies --role-name "${role_nm}" --query "AttachedPolicies[].PolicyName" \
       --output text)"
   exit_code=$? 
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the policies attached to the role.'
      return "${exit_code}" 
   fi   
        
   # Detach the role from the instance profiles.
   for profile_nm in ${instance_profiles}
   do
      __remove_role_from_instance_profile "${profile_nm}" "${role_nm}" > /dev/null
      exit_code=$?
      
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: removing role from instance profile.'
         return "${exit_code}"
      else 
         echo 'Role removed from instance profile.'
      fi      
   done
      
   # Detach the policies from role.
   for policy_nm in ${policies}
   do
      __detach_permission_policy_from_role "${role_nm}" "${policy_nm}" > /dev/null
      exit_code=$?
      
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: detaching permission policy from role.'
         return "${exit_code}"
      else 
         echo 'Permission policy removed from role.'
      fi      
   done 
    
   aws iam delete-role --role-name "${role_nm}" > /dev/null
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting role.'
   fi  
   
   return "${exit_code}" 
}

#===============================================================================
# Checks if a IAM role exists.
#
# Globals:
#  None
# Arguments:
# +role_nm -- the role name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function check_role_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   declare -r role_nm="${1}"
   local role_id=''
   local exists='false'
   local exit_code=0

   get_role_id "${role_nm}"
   exit_code=$?
   role_id="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving role.'
      return "${exit_code}"
   fi
   
   if [[ -n "${role_id}" ]]
   then
      exists='true'
   fi
       
   __RESULT="${exists}"      
   
   return 0
}

#===============================================================================
# Returns a IAM role's ARN.
#
# Globals:
#  None
# Arguments:
# +role_nm -- the role name.
# Returns:      
#  the role's ARN in the __RESULT global variable.  
#===============================================================================
function get_role_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   declare -r role_nm="${1}"
   local role_arn=''
   local exit_code=0

   role_arn="$(aws iam list-roles --query "Roles[? RoleName=='${role_nm}'].Arn" --output text)"
   exit_code=$?
       
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving role ARN.'
      return "${exit_code}"
   fi
   
   if [[ -z "${role_arn}" ]]
   then
      echo 'Role not found.'
   fi
   
   __RESULT="${role_arn}" 
       
   return "${exit_code}" 
}

#===============================================================================
# Returns a role's ID, or blanck if the role is not found.
#
# Globals:
#  None
# Arguments:
# +role_nm   -- the role name.
# Returns:      
#  the role ID in the __RESULT global variable.  
#===============================================================================
function get_role_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r role_nm="${1}"
   local exit_code=0
   local role_id=''

   role_id="$(aws iam list-roles \
       --query "Roles[? RoleName=='${role_nm}'].RoleId" --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving role.'
      return "${exit_code}"
   fi
   
   __RESULT="${role_id}" 
       
   return "${exit_code}" 
}

#===============================================================================
# Creates an instance profile. Amazon EC2 uses an instance profile as a 
# container for an IAM role. An instance profile can contain only one IAM role. 
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# Returns:      
#  none.  
#===============================================================================
function create_instance_profile()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r profile_nm="${1}"
   local exit_code=0

   aws iam create-instance-profile --instance-profile-name "${profile_nm}" \
       > /dev/null
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating instance profile.'
   fi

   return "${exit_code}" 
}

#===============================================================================
# Deletes the specified instance profile. If the instance profile has a role 
# associated, the role is removed.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# Returns:      
#  none.  
#===============================================================================
function delete_instance_profile()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   declare -r profile_nm="${1}"
   local role_nm=''
   local exit_code=0
   
   # Retrieve role attached to the instance profiles.
   # Only one role can be attached to an instance profile.
   role_nm="$(aws iam list-instance-profiles \
       --query "InstanceProfiles[? InstanceProfileName=='${profile_nm}' ].Roles[].RoleName" --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the role attached to the instance profile.' 
      return "${exit_code}"
   fi

   # Detach the role from the instance profile.
   __remove_role_from_instance_profile "${profile_nm}" "${role_nm}" > /dev/null
      exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: removing role from instance profile.'
      return "${exit_code}"
   fi
   
   aws iam delete-instance-profile --instance-profile-name "${profile_nm}" > /dev/null
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting instance profile.'
   fi

   return "${exit_code}" 
}

#===============================================================================
# Checks if a IAM instance profile exists.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the instance profile name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function check_instance_profile_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   declare -r profile_nm="${1}"
   local profile_id=''
   local exists='false'
   local exit_code=0

   get_instance_profile_id "${profile_nm}"
   exit_code=$?
   profile_id="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance profile.'
      return "${exit_code}"
   fi
   
   if [[ -n "${profile_id}" ]]
   then
      exists='true'
   fi
       
   __RESULT="${exists}"      
   
   return 0
}

#===============================================================================
# Returns an instance profile's ID.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the instance profile name.
# Returns:      
#  the instance profile ID in the __RESULT global variable. 
#===============================================================================
function get_instance_profile_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r profile_nm="${1}"
   local profile_id=''
   local exit_code=0

   profile_id="$(aws iam list-instance-profiles \
       --query "InstanceProfiles[?InstanceProfileName=='${profile_nm}'].InstanceProfileId" \
       --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting instance profile ID.'
      return "${exit_code}"
   fi 
  
   __RESULT="${profile_id}"

   return 0
}

#===============================================================================
# Checks if the specified instance profile has a role associated.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# +role_nm    -- the role name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function check_instance_profile_has_role_associated()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi    
    
   __RESULT=''
   declare -r profile_nm="${1}"
   declare -r role_nm="${2}"
   local exit_code=0
   local associated='false'
   local role_exists=''
   local profile_exists=''
   local role_found=''
   
   check_role_exists "${role_nm}"
   exit_code=$?
   role_exists="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the role.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${role_exists}" ]]
   then
      echo 'ERROR: role not found.' 
      return 1
   fi
   
   check_instance_profile_exists "${profile_nm}"
   exit_code=$?
   profile_exists="${__RESULT}"
   __RESULT=''
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the instance profile.' 
      return "${exit_code}"
   fi
   
   if [[ 'false' == "${profile_exists}" ]]
   then
      echo 'ERROR: instance profile not found.' 
      return 1
   fi
    
   # One role per instance profile. 
   role_found="$(aws iam list-instance-profiles \
       --query "InstanceProfiles[? InstanceProfileName == '${profile_nm}' ].Roles[].RoleName" \
       --output text)"

   exit_code=$?
   
   if [[ 0 -eq "${exit_code}" ]]
   then
      if [[ "${role_nm}" == "${role_found}" ]]
      then
         associated='true' 
      fi
   fi
   
   __RESULT="${associated}"
   
   return "${exit_code}"
}

#===============================================================================
# Associates a role to an instance profile. 
#Amazon EC2 uses an instance profile as a  container for an IAM role.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# +role_nm    -- the role name.
# Returns:      
#  none.  
#===============================================================================
function associate_role_to_instance_profile()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r profile_nm="${1}"
   declare -r role_nm="${2}"
   local exit_code=0
   
   aws iam add-role-to-instance-profile --instance-profile-name "${profile_nm}" \
       --role-name "${role_nm}" > /dev/null
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: associating role to instance profile.'
   fi

   return "${exit_code}" 
}

#===============================================================================
# Removes the specified IAM role from the specified EC2 instance profile.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# +role_nm    -- the role name.
# Returns:      
#  none.  
#===============================================================================
function __remove_role_from_instance_profile()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   declare -r profile_nm="${1}"
   declare -r role_nm="${2}"
   local exit_code=0
   
   aws iam remove-role-from-instance-profile --instance-profile-name "${profile_nm}" \
       --role-name "${role_nm}" > /dev/null

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: removing role from instance profile.'
   fi

   return "${exit_code}" 
}

