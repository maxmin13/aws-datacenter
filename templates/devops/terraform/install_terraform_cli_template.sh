#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BBL client and Terraform and add them to the PATH.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
TERRAFORM_CLI_DOWNLOAD_URL='SEDterraform_download_urlSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

# Check if Terraform is already installed

set +e
terraform -v
exit_code=$?
set -e

if [[ 0 -eq "${exit_code}" ]]
then
   echo 'WARN: Terraform client already installed.'
   exit 0
fi

echo 'Installig Terraform client ...'

cd "${script_dir}" || exit
rm -rf temp
mkdir -p temp && cd temp || exit

wget "${TERRAFORM_CLI_DOWNLOAD_URL}"
unzip -j ./*zip 
rm ./*zip
file_name="$(ls)"
mv "${file_name}" /usr/bin/terraform
chmod 500 /usr/bin/terraform

terraform -v

echo 'Terraform client installed.'

exit 0

