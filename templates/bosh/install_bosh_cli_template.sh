#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH client.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

cd "${script_dir}" || exit

echo 'Downloading Bosh client ...'

wget https://github.com/cloudfoundry/bosh-cli/releases/download/v6.4.5/bosh-cli-6.4.5-linux-amd64

chmod +x bosh-cli-6.4.5-linux-amd64
cp bosh-cli-6.4.5-linux-amd64 /usr/bin/bosh
chmod 700 /usr/bin/bosh

echo 'Bosh client installed.'

bosh -v

yum install -y gcc gcc-c++ ruby ruby-devel mysql-devel postgresql-devel postgresql-libs \
    sqlite-devel libxslt-devel libxml2-devel patch openssl
gem install yajl-ruby

echo 'Dependencies installed.'

exit 0

