#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../datacenter && pwd)"

source "${PROJECT_DIR}"/amazon/lib/project_dirs.sh
source "${PROJECT_DIR}"/amazon/lib/app_consts.sh
source "${PROJECT_DIR}"/amazon/lib/archives.sh
source "${PROJECT_DIR}"/amazon/lib/ssh_utils.sh
source "${PROJECT_DIR}"/amazon/lib/general_utils.sh
source "${PROJECT_DIR}"/amazon/lib/httpd_utils.sh
source "${PROJECT_DIR}"/amazon/lib/aws/rds.sh
source "${PROJECT_DIR}"/amazon/lib/aws/ec2.sh
source "${PROJECT_DIR}"/amazon/lib/aws/elb.sh
source "${PROJECT_DIR}"/amazon/lib/aws/iam.sh
source "${PROJECT_DIR}"/amazon/lib/aws/sts.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53/route53.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains.sh

log_file="${LOG_DIR}"/test-$(date +"%d-%m-%Y-%H.%M"."%S")
 
echo

{
   if [[ 'production' == "${ENV}" ]]
   then
      echo '*********************'
      echo 'Env: production (AWS)'
      echo '*********************'
   elif [[ 'development' == "${ENV}" ]]
   then
      echo '****************'
      echo 'Env: development'
      echo '****************' 
   fi
   
   echo

   # Route 53 tests.
   . "${PROJECT_DIR}"/amazon/lib/aws/route53/test/make.sh  
   
} ### >> "${log_file}" 2>&1  

echo
echo 'Tests completed'
echo   
