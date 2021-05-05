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

echo ''

if [[ 'production' == "${ENV}" ]]
then
   echo '***************'
   echo 'Env: production'
   echo '***************'
elif [[ 'development' == "${ENV}" ]]
then
   echo '****************'
   echo 'Env: development'
   echo '****************' 
fi

echo ''

# Create the server instances.
. "${PROJECT_DIR}"/amazon/datacenter/make.sh
. "${PROJECT_DIR}"/amazon/images/database/make.sh
. "${PROJECT_DIR}"/amazon/images/shared/make.sh
. "${PROJECT_DIR}"/amazon/images/loadbalancer/make.sh
. "${PROJECT_DIR}"/amazon/images/admin/make.sh
. "${PROJECT_DIR}"/amazon/images/webphp/make.sh 1
#. "${PROJECT_DIR}"/amazon/images/webphp/make.sh 2

# Deploy Database, Admin site, public WebPhp sites.
. "${PROJECT_DIR}"/amazon/deploy/database/make.sh
. "${PROJECT_DIR}"/amazon/deploy/admin/make.sh
. "${PROJECT_DIR}"/amazon/deploy/webphp/make.sh 1
#. "${PROJECT_DIR}"/amazon/deploy/webphp/make.sh 2

echo 'Data Center up and running'
echo
