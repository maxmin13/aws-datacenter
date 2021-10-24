#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

function bbl_plan_director()
{
   if [[ $# -lt 7 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local exit_code=0
   declare -r bbl_dir="${1}"
   declare -r access_key_id="${2}"
   declare -r secret_access_key="${3}"
   declare -r region="${4}"
   declare -r lbal_cert="${5}"
   declare -r lbal_key="${6}"
   declare -r lbal_domain="${7}"
   
   __bbl_run_cmd 'plan' "${bbl_dir}" "${access_key_id}" "${secret_access_key}" "${region}" \
       "${lbal_cert}" "${lbal_key}" "${lbal_domain}"
         
   exit_code=$?
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: planning BOSH director.'
   fi
    
   find "${bbl_dir}" -type f -exec chmod 700 {} + 
   find "${bbl_dir}" -type d -exec chmod 700 {} + 
    
   return "${exit_code}"       
}

function bbl_bootstrap_director()
{
   if [[ $# -lt 7 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local exit_code=0
   declare -r bbl_dir="${1}"
   declare -r access_key_id="${2}"
   declare -r secret_access_key="${3}"
   declare -r region="${4}"
   declare -r lbal_cert="${5}"
   declare -r lbal_key="${6}"
   declare -r lbal_domain="${7}"
   
   __bbl_run_cmd 'up' "${bbl_dir}" "${access_key_id}" "${secret_access_key}" "${region}" \
       "${lbal_cert}" "${lbal_key}" "${lbal_domain}"
         
   exit_code=$?
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: bootstapping BOSH director.'
   fi

   return "${exit_code}"       
}
    
function bbl_delete_director()
{
   if [[ $# -lt 7 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local exit_code=0
   declare -r bbl_dir="${1}"
   declare -r access_key_id="${2}"
   declare -r secret_access_key="${3}"
   declare -r region="${4}"
   declare -r lbal_cert="${5}"
   declare -r lbal_key="${6}"
   declare -r lbal_domain="${7}"
   
   if [[ -d "${bbl_dir}" ]]
   then
      __bbl_run_cmd 'down' "${bbl_dir}" "${access_key_id}" "${secret_access_key}" "${region}" \
          "${lbal_cert}" "${lbal_key}" "${lbal_domain}"       
      exit_code=$?      
   else
      echo 'WARN: BOSH bootloader not found, command not run.'
   fi
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting BOSH director.'
   fi
    
   return "${exit_code}"       
}

function __bbl_run_cmd()
{  
   if [[ $# -lt 8 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local exit_code=0
   declare -r cmd="${1}"
   declare -r bbl_dir="${2}"
   declare -r access_key_id="${3}"
   declare -r secret_access_key="${4}"
   declare -r region="${5}"
   declare -r lbal_cert="${6}"
   declare -r lbal_key="${7}"
   declare -r lbal_domain="${8}"
   
   if [[ 'up' != "${cmd}" && 'down' != "${cmd}" && 'plan' != "${cmd}" ]]
   then
      echo 'ERROR: wrong command name.'
      return 1
   fi
   
   bbl "${cmd}" \
       --iaas aws \
       --state-dir "${bbl_dir}" \
       --aws-access-key-id "${access_key_id}" \
       --aws-secret-access-key "${secret_access_key}" \
       --aws-region "${region}" \
       --lb-type cf \
       --lb-cert "${lbal_cert}" \
       --lb-key "${lbal_key}" \
       --lb-domain "${lbal_domain}" \
       --no-confirm \
       --debug
       
    exit_code=$?
    
    if [[ 0 -ne "${exit_code}" ]]
    then
       echo 'ERROR: running BBL command.'
    fi
     
    return "${exit_code}"
}

## Forces deleting all account resources whose name begin by '$filter_nm'
function bbl_cleanup_orphaned_resources()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local exit_code=0
   declare -r access_key_id="${1}"
   declare -r secret_access_key="${2}"
   declare -r filter_nm="${3}"
   declare -r region="${4}"
   
   if [[ -z "${filter_nm}" ]]
   then
      ## If blank, anything in the account is deleted.
      echo 'ERROR: filter name must be specified.'
      exit 1
   fi
   
   bbl cleanup-leftovers \
       --filter "${filter_nm}" \
       --iaas aws \
       --aws-region "${region}" \
       --aws-access-key-id "${access_key_id}" \
       --aws-secret-access-key "${secret_access_key}" \
       --no-confirm \
       --debug
       
    exit_code=$?
    
    if [[ 0 -ne "${exit_code}" ]]
    then
       echo 'ERROR: running BBL command.'
    fi
     
    return "${exit_code}"       
}

function bbl_export_environment()
{  
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local exit_code=0
   declare -r bbl_dir="${1}"
   
   eval "$(bbl --state-dir "${bbl_dir}" print-env)"
       
   exit_code=$?
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: exporting BBL environment.'
   fi
     
   return "${exit_code}"
}

