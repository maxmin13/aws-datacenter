#!/usr/bin/bash

# shellcheck disable=SC1091,SC2155

set +o errexit
set +o pipefail
set +o nounset
set +o xtrace

export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../../datacenter && pwd)"

source "${PROJECT_DIR}"/amazon/lib/const/app_consts.sh
source "${PROJECT_DIR}"/amazon/lib/const/project_dirs.sh
source "${PROJECT_DIR}"/amazon/lib/const/archives.sh
source "${PROJECT_DIR}"/amazon/lib/const/dev_consts.sh
source "${PROJECT_DIR}"/amazon/lib/utils/ssh/ssh_utils.sh
source "${PROJECT_DIR}"/amazon/lib/utils/general_utils.sh
source "${PROJECT_DIR}"/amazon/lib/utils/httpd_utils.sh
source "${PROJECT_DIR}"/amazon/lib/aws/rds.sh
source "${PROJECT_DIR}"/amazon/lib/aws/ec2/ec2.sh
source "${PROJECT_DIR}"/amazon/lib/aws/elb.sh
source "${PROJECT_DIR}"/amazon/lib/aws/iam/iam.sh
source "${PROJECT_DIR}"/amazon/lib/aws/sts.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53/route53.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains.sh

###log_file="${LOG_DIR}"/test-$(date +"%d-%m-%Y-%H.%M"."%S")
 
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
   
   # SSH utils tests.
   . "${PROJECT_DIR}"/amazon/lib/utils/ssh/test/make.sh
       
   # EC2 tests.
   . "${PROJECT_DIR}"/amazon/lib/aws/ec2/test/make.sh
    
   # IAM tests.
   . "${PROJECT_DIR}"/amazon/lib/aws/iam/test/make.sh 

   # Route 53 tests.
   . "${PROJECT_DIR}"/amazon/lib/aws/route53/test/make.sh  
      
} ### >> "${log_file}" 2>&1  

echo
echo 'Tests completed'
echo   
