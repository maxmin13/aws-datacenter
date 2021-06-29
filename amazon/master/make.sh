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
source "${PROJECT_DIR}"/amazon/lib/aws/route53/route53.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains.sh
source "${PROJECT_DIR}"/amazon/credential/recaptcha.sh
source "${PROJECT_DIR}"/amazon/credential/passwords.sh
source "${PROJECT_DIR}"/amazon/credential/ssl.sh

log_file="${LOG_DIR}"/make-$(date +"%d-%m-%Y-%H.%M"."%S")
 
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
   
    . "${PROJECT_DIR}"/amazon/lib/aws/route53/test/make.sh 
    exit
      
   # Create the datacenter.
   . "${PROJECT_DIR}"/amazon/datacenter/make.sh              

   # Create a base shared image.
   . "${PROJECT_DIR}"/amazon/shared/box/make.sh              
   . "${PROJECT_DIR}"/amazon/shared/image/make.sh            
   . "${PROJECT_DIR}"/amazon/shared/box/delete.sh            

   # Create the server instances.
   . "${PROJECT_DIR}"/amazon/database/box/make.sh            
   . "${PROJECT_DIR}"/amazon/loadbalancer/box/make.sh        
   . "${PROJECT_DIR}"/amazon/admin/box/make.sh               
   . "${PROJECT_DIR}"/amazon/webphp/box/make.sh 1                  

   # Deploy Database objects.
   . "${PROJECT_DIR}"/amazon/database/box/data/make.sh       

   # Deploy admin website and public webphp websites.
   . "${PROJECT_DIR}"/amazon/admin/box/website/make.sh      
   . "${PROJECT_DIR}"/amazon/webphp/box/website/make.sh 1   
   
   # Register 'maxmin.it' domain with the AWS registrar.
   . "${PROJECT_DIR}"/amazon/dns/domain/registration/make.sh 

   # Create the hosted zone that handles the application DNS records.
   . "${PROJECT_DIR}"/amazon/dns/hostedzone/make.sh      

   # Configure SSL in the Admin instance.
   . "${PROJECT_DIR}"/amazon/admin/box/ssl/make.sh     
              
} ### >> "${log_file}" 2>&1  

echo
echo 'Data Center up and running'
echo
