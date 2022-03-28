#!/bin/bash

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
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains/route53domains.sh

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

   # Make a backup of the database.
   . "${PROJECT_DIR}"/amazon/database/data/backup/make.sh 

   # Delete the application DNS records.
   . "${PROJECT_DIR}"/amazon/dns/hostedzone/records/delete.sh
          
   # Delete the websites.
   . "${PROJECT_DIR}"/amazon/instance/admin/website/delete.sh      
   . "${PROJECT_DIR}"/amazon/instance/webphp/website/delete.sh 1
   . "${PROJECT_DIR}"/amazon/instance/webphp/website/delete.sh 2

   # Delete the database objects.
   . "${PROJECT_DIR}"/amazon/database/data/delete.sh
      
   # Delete the server instances.
   . "${PROJECT_DIR}"/amazon/instance/shared/delete.sh  
   . "${PROJECT_DIR}"/amazon/instance/webphp/delete.sh 1           
   . "${PROJECT_DIR}"/amazon/instance/webphp/delete.sh 2
   . "${PROJECT_DIR}"/amazon/instance/admin/delete.sh 
   
   # Delete load balancer
   . "${PROJECT_DIR}"/amazon/loadbalancer/delete.sh     
   
   # Delete the database.
   . "${PROJECT_DIR}"/amazon/database/delete.sh              

   # Delete the Shared image.
   . "${PROJECT_DIR}"/amazon/image/shared/delete.sh            

   # Release the public IP addresses assigned to the account.
   . "${PROJECT_DIR}"/amazon/account/delete.sh  
   
   # Delete AWS users and policies.
   . "${PROJECT_DIR}"/amazon/user/delete.sh                

   # Delete the datacenter.
   . "${PROJECT_DIR}"/amazon/datacenter/delete.sh    

} ### >> "${log_file}" 2>&1        

echo
echo 'Data center deleted'
echo
