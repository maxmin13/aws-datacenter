#!/bin/bash

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
 
export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../aws-datacenter && pwd)"

source "${PROJECT_DIR}"/amazon/lib/const/app_consts.sh
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
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains.sh

##### log_file="${LOG_DIR}"/make-$(date +"%d-%m-%Y-%H.%M"."%S")

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
  
   # Create the datacenter.
   . "${PROJECT_DIR}"/amazon/datacenter/make.sh  
      
   # Create AWS users and policies
   . "${PROJECT_DIR}"/amazon/user/make.sh             

   # Create a base shared image.
   . "${PROJECT_DIR}"/amazon/shared/instance/make.sh              
   . "${PROJECT_DIR}"/amazon/shared/image/make.sh            
   . "${PROJECT_DIR}"/amazon/shared/instance/delete.sh  
   
   # Create database and load balancer.
   . "${PROJECT_DIR}"/amazon/database/make.sh            
   . "${PROJECT_DIR}"/amazon/loadbalancer/make.sh             

   # Create the Admin and Webphp instances.      
   . "${PROJECT_DIR}"/amazon/admin/instance/make.sh               
   . "${PROJECT_DIR}"/amazon/webphp/instance/make.sh 2   
   
   # Deploy database objects.
   . "${PROJECT_DIR}"/amazon/database/data/make.sh       

   # Deploy Admin and Webphp websites.
   . "${PROJECT_DIR}"/amazon/admin/instance/website/make.sh      
   . "${PROJECT_DIR}"/amazon/webphp/instance/website/make.sh 2
   
   # Register 'maxmin.it' domain with the AWS DNS registrar.
   . "${PROJECT_DIR}"/amazon/dns/domain/registration/make.sh 

   # Create the application DNS hosted zone.
   . "${PROJECT_DIR}"/amazon/dns/hostedzone/make.sh
   
   # Configure SSL in the Admin instance.
   . "${PROJECT_DIR}"/amazon/admin/instance/ssl/make.sh    
   
   # Configure SSL in the load balancer in front of Webphp applications.
   . "${PROJECT_DIR}"/amazon/loadbalancer/ssl/make.sh      
 
} ### >> "${log_file}" 2>&1  

echo
echo 'Data Center up and running'
echo
