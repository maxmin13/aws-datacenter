#!/bin/bash

set -o errexit
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
source "${PROJECT_DIR}"/amazon/lib/aws/route53.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains.sh
source "${PROJECT_DIR}"/amazon/credential/recaptcha.sh
source "${PROJECT_DIR}"/amazon/credential/passwords.sh

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
   
   exit
   exit
   exit

   echo 

   ### TODO mysqldump: command not found
   # Make a backup of the database.
   #. "${PROJECT_DIR}"/amazon/database/box/data/backup/make.sh 

   ## TODO
   # Delete the application hosted zone
   #. "${PROJECT_DIR}"/amazon/dns/hostedzone/delete.sh         

   # Delete the websites.
   . "${PROJECT_DIR}"/amazon/admin/box/website/delete.sh      
   . "${PROJECT_DIR}"/amazon/webphp/box/website/delete.sh 1   

   # Delete SSL 
   ## TODO . "${PROJECT_DIR}"/amazon/ssl/admin/delete.sh

   # Delete the server instances.
   . "${PROJECT_DIR}"/amazon/shared/box/delete.sh             
   . "${PROJECT_DIR}"/amazon/webphp/box/delete.sh 1          
   . "${PROJECT_DIR}"/amazon/loadbalancer/box/delete.sh       

   ### TODO: /home/admin-user/script/delete_database.sh: line 17: mysql: command not found
   # Delete the Database objects.
  ## . "${PROJECT_DIR}"/amazon/database/box/data/delete.sh

   # Delete the Admin instance.
   . "${PROJECT_DIR}"/amazon/admin/box/delete.sh                 

   # Delete the Database instance.
   . "${PROJECT_DIR}"/amazon/database/box/delete.sh              

   # Delete the Shared instance.
   . "${PROJECT_DIR}"/amazon/shared/image/delete.sh            

   # Release the IP addresses.
   . "${PROJECT_DIR}"/amazon/account/delete.sh               

   # Delete the datacenter.
   . "${PROJECT_DIR}"/amazon/datacenter/delete.sh    

} ### >> "${log_file}" 2>&1        

echo
echo 'Data center deleted'
echo
