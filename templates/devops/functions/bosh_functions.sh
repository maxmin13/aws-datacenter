#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

function bosh_login_director()
{   
   : "${BOSH_ENVIRONMENT:?$' environment variable is needed.'}"
   : "${BOSH_CA_CERT:?$' environment variable is needed.'}"
   : "${BOSH_CLIENT:?$' environment variable is needed.'}"
   : "${BOSH_CLIENT_SECRET:?' environment variable is needed.'}"
   : "${BOSH_ALL_PROXY:?' environment variable is needed.'}"

   bosh login 
       
   exit_code=$?
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: logging into BOSH director.'
   fi
    
   return "${exit_code}"       
}
    
function bosh_logout_director()
{
   : "${BOSH_ENVIRONMENT:?$' environment variable is needed.'}"
   : "${BOSH_ALL_PROXY:?' environment variable is needed.'}"
    
   bosh logout 
       
   exit_code=$?
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: logging into BOSH director.'
   fi
    
   return "${exit_code}"   
}

function bosh_upload_stemcell()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   declare -r stemcell_url="${1}"
   
   bosh upload-stemcell "${stemcell_url}"
   
   exit_code=$?
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: uploading stem-cell to BOSH director.'
   fi
    
   return "${exit_code}"   
}   

function bosh_deploy_cloud_foundry()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   declare -r deployment_nm="${1}"
   declare -r cf_lbal_domain="${2}"
   declare -r cf_install_dir="${3}"
   
   # the files: use-bionic-stemcell.yml and vars.yml are expected in the cf install dir.
   
   bosh -n -d "${deployment_nm}" deploy "${cf_install_dir}"/cf-deployment/cf-deployment.yml \
        -o "${cf_install_dir}"/cf-deployment/operations/aws.yml \
        -o "${cf_install_dir}"/cf_use_bionic_stemcell.yml \
        -v system_domain="${cf_lbal_domain}" \
        --vars-file "${cf_install_dir}"/cf_vars.yml
          
   exit_code=$?
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deploying Cloud Foundry.'
   fi
    
   return "${exit_code}"   
}   

function bosh_delete_cloud_foundry()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   declare -r deployment_nm="${1}"
     
   bosh -n -d "${deployment_nm}" delete-deployment 
   
   exit_code=$?
    
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting Cloud Foundry.'
   fi
    
   return "${exit_code}"   
}


