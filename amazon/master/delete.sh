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
source "${PROJECT_DIR}"/amazon/credential/recaptcha.sh
source "${PROJECT_DIR}"/amazon/credential/passwords.sh

log_file="${LOG_DIR}"/delete-$(date +"%d-%m-%Y-%H.%M"."%S")

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

echo

# Make a backup of the database.
. "${PROJECT_DIR}"/amazon/database/data/backup/make.sh    ### >> "${log_file}" 2>&1

# Delete the websites.
. "${PROJECT_DIR}"/amazon/admin/website/delete.sh         ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/webphp/website/delete.sh 1      ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/webphp/website/delete.sh 2      ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/webphp/website/delete.sh 3      ### >> "${log_file}" 2>&1

# Delete the server instances.
. "${PROJECT_DIR}"/amazon/webphp/delete.sh 1              ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/webphp/delete.sh 2              ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/webphp/delete.sh 3              ### >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/loadbalancer/delete.sh          ### >> "${log_file}" 2>&1

# Delete the database objects.
. "${PROJECT_DIR}"/amazon/database/data/delete.sh

# Delete the Admin instance.
. "${PROJECT_DIR}"/amazon/admin/delete.sh                 ### >> "${log_file}" 2>&1

# Delete the database instance.
. "${PROJECT_DIR}"/amazon/database/delete.sh              ### >> "${log_file}" 2>&1

# Delete the shared base instance.
. "${PROJECT_DIR}"/amazon/image/shared/delete.sh          ### >> "${log_file}" 2>&1

# Release the IP addresses.
. "${PROJECT_DIR}"/amazon/account/delete.sh               ### >> "${log_file}" 2>&1

# Delete the datacenter.
. "${PROJECT_DIR}"/amazon/datacenter/delete.sh            ### >> "${log_file}" 2>&1

# Delete the application hosted zone
. "${PROJECT_DIR}"/amazon/dns/hostedzone/delete.sh        ### >> "${log_file}" 2>&1


echo 'Data center deleted'
echo
