#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH client and add it to the PATH.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
BOSH_CLI_DOWNLOAD_URL='SEDbosh_cli_download_urlSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

cd "${script_dir}" || exit

# Check if BOSH is already installed

set +e
bosh -v
exit_code=$?
set -e

if [[ 0 -eq "${exit_code}" ]]
then
   echo 'WARN: BOSH client already installed.'
   exit 0
fi

echo 'Installig BOSH client ...'

rm -rf temp
mkdir -p temp && cd temp || exit
wget "${BOSH_CLI_DOWNLOAD_URL}"
file_name="$(ls)"
mv "${file_name}" /usr/bin/bosh
chmod 500 /usr/bin/bosh
 
bosh -v

echo 'BOSH client installed.'

yum install -y gcc gcc-c++ ruby ruby-devel mysql-devel postgresql-devel postgresql-libs \
    sqlite-devel libxslt-devel libxml2-devel patch openssl
    
gem install yajl-ruby

echo 'Bosh client dependencies installed.'

exit 0

