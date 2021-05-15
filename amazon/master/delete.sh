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

echo

. "${PROJECT_DIR}"/amazon/images/database/delete.sh     >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/images/webphp/delete.sh 1     >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/images/webphp/delete.sh 2     >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/images/webphp/delete.sh 3     >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/images/admin/delete.sh        >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/images/shared/delete.sh       >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/images/loadbalancer/delete.sh >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/datacenter/delete.sh          >> "${log_file}" 2>&1
. "${PROJECT_DIR}"/amazon/account/delete.sh             >> "${log_file}" 2>&1

#. "${PROJECT_DIR}"/amazon/website/admin/delete.sh       >> "${log_file}" 2>&1
#. "${PROJECT_DIR}"/amazon/website/webphp/delete.sh 1    >> "${log_file}" 2>&1

echo 'Data Center deleted'
