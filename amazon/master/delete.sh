#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
 
export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../datacenter && pwd)"

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

log_file="${LOG_DIR}"/delete-$(date +"%d-%m-%Y-%H.%M"."%S")

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
      
   # Remove Cloud Foundry components.
   . "${PROJECT_DIR}"/amazon/bosh/delete.sh  

   # Make a backup of the database.
   . "${PROJECT_DIR}"/amazon/database/data/backup/make.sh 

   # Delete the application DNS hosted zone
   . "${PROJECT_DIR}"/amazon/dns/hostedzone/delete.sh  
          
   # Delete the websites.
   . "${PROJECT_DIR}"/amazon/admin/instance/website/delete.sh      
   . "${PROJECT_DIR}"/amazon/webphp/instance/website/delete.sh 1

   # Delete the database objects.
   . "${PROJECT_DIR}"/amazon/database/data/delete.sh
      
   # Delete the server instances.
   . "${PROJECT_DIR}"/amazon/shared/instance/delete.sh             
   . "${PROJECT_DIR}"/amazon/webphp/instance/delete.sh 1   
   . "${PROJECT_DIR}"/amazon/admin/instance/delete.sh 
   
   # Delete load balancer
   . "${PROJECT_DIR}"/amazon/loadbalancer/delete.sh     
   
   # Delete the database.
   . "${PROJECT_DIR}"/amazon/database/delete.sh              

   # Delete the Shared instance.
   . "${PROJECT_DIR}"/amazon/shared/image/delete.sh            

   # Release the public IP addresses assigned to the account.
   . "${PROJECT_DIR}"/amazon/account/delete.sh  
   
   # Delete AWS users and policies.
   ### TODO error deleting role, policy must be detached.
   . "${PROJECT_DIR}"/amazon/user/delete.sh                

   # Delete the datacenter.
   . "${PROJECT_DIR}"/amazon/datacenter/delete.sh    

} ### >> "${log_file}" 2>&1        

echo
echo 'Data center deleted'
echo
