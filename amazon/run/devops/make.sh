#!/bin/bash

#####################################################################################
# Checks if the datacenter and the Admin instance are running, if not, create them.
# The Admin box is used as a jump-box to install Bosh director and Cloudfoundry in a 
# dedicated VPC. 
#####################################################################################

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
 
export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../../aws-datacenter && pwd)"

source "${PROJECT_DIR}"/amazon/lib/const/app_consts.sh
source "${PROJECT_DIR}"/amazon/lib/const/devops/devops_consts.sh
source "${PROJECT_DIR}"/amazon/lib/const/project_dirs.sh
source "${PROJECT_DIR}"/amazon/lib/const/archives.sh
source "${PROJECT_DIR}"/amazon/lib/const/dev_consts.sh
source "${PROJECT_DIR}"/amazon/lib/utils/ssh/ssh_utils.sh
source "${PROJECT_DIR}"/amazon/lib/utils/general_utils.sh
source "${PROJECT_DIR}"/amazon/lib/utils/httpd_utils.sh
source "${PROJECT_DIR}"/amazon/lib/credential/recaptcha.sh
source "${PROJECT_DIR}"/amazon/lib/credential/passwords.sh
source "${PROJECT_DIR}"/amazon/lib/aws/rds.sh
source "${PROJECT_DIR}"/amazon/lib/aws/ec2/ec2.sh
source "${PROJECT_DIR}"/amazon/lib/aws/elb.sh
source "${PROJECT_DIR}"/amazon/lib/aws/iam/iam.sh
source "${PROJECT_DIR}"/amazon/lib/aws/sts.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53/route53.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains/route53domains.sh

##### log_file="${LOG_DIR}"/make-$(date +"%d-%m-%Y-%H.%M"."%S")

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
   
   # Create the datacenter.
   . "${PROJECT_DIR}"/amazon/datacenter/make.sh  
      
   # Create AWS users and policies
   . "${PROJECT_DIR}"/amazon/user/make.sh
   
   
   # Create database.
   . "${PROJECT_DIR}"/amazon/database/make.sh                  

   # Create a base shared image.
   . "${PROJECT_DIR}"/amazon/instance/shared/make.sh              
   . "${PROJECT_DIR}"/amazon/image/shared/make.sh            
   . "${PROJECT_DIR}"/amazon/instance/shared/delete.sh  
 
    # Create the Admin instance.      
   . "${PROJECT_DIR}"/amazon/instance/admin/make.sh  
   
   # Create AWS devops users and policies
   . "${PROJECT_DIR}"/amazon/user/devops/make.sh        
 
   # Install devops components 
   . "${PROJECT_DIR}"/amazon/devops/make.sh   
 
} ### >> "${log_file}" 2>&1  

echo
echo 'Devops components up and running'
echo
