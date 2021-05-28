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
source "${PROJECT_DIR}"/amazon/lib/aws/route53domains.sh
source "${PROJECT_DIR}"/amazon/lib/aws/route53.sh
source "${PROJECT_DIR}"/amazon/credential/recaptcha.sh
source "${PROJECT_DIR}"/amazon/credential/passwords.sh

log_file="${LOG_DIR}"/make-$(date +"%d-%m-%Y-%H.%M"."%S")

echo ''

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


#. "${PROJECT_DIR}"/amazon/admin/website/delete.sh
#. "${PROJECT_DIR}"/amazon/admin/website/make.sh 
. "${PROJECT_DIR}"/amazon/webphp/website/delete.sh 1            
. "${PROJECT_DIR}"/amazon/webphp/website/make.sh 1
. "${PROJECT_DIR}"/amazon/dns/hostedzone/make.sh



exit
exit




echo

# Create the datacenter.
. "${PROJECT_DIR}"/amazon/datacenter/make.sh            ### >> "${log_file}" 2>&1

# Create a base shared image.
. "${PROJECT_DIR}"/amazon/image/shared/make.sh          ### >> "${log_file}" 2>&1

# Create the server instances.
. "${PROJECT_DIR}"/amazon/database/make.sh              ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/loadbalancer/make.sh          ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/admin/make.sh                 ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/webphp/make.sh 1              ### >> "${log_file}" 2>&1
##. "${PROJECT_DIR}"/amazon/webphp/make.sh 2              ### >> "${log_file}" 2>&1

# Deploy database objects
. "${PROJECT_DIR}"/amazon/database/data/make.sh

# Deploy admin website and public webphp websites.
. "${PROJECT_DIR}"/amazon/admin/website/make.sh         ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/webphp/website/make.sh 1      ### >> "${log_file}" 2>&1
##. "${PROJECT_DIR}"/amazon/webphp/website/make.sh 2      ### >> "${log_file}" 2>&1

# Register 'maxmin.it' domain with the AWS registrar.
. "${PROJECT_DIR}"/amazon/dns/domain/registration/make.sh

# Create the hosted zone that handles the application DNS records.
. "${PROJECT_DIR}"/amazon/dns/hostedzone/make.sh

echo 'Data Center up and running'
echo
