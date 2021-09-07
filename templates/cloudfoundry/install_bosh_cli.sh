#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH client.
####################################################################

echo 'Downloading Bosh client ...'

wget https://github.com/cloudfoundry/bosh-cli/releases/download/v6.4.5/bosh-cli-6.4.5-linux-amd64

chmod +x bosh-cli-6.4.5-linux-amd64
cp bosh-cli-6.4.5-linux-amd64 /usr/local/bin/bosh

bosh -v

echo 'Bosh client installed.'

echo 'Installing dependencies ...'

yum install -y gcc gcc-c++ ruby ruby-devel mysql-devel postgresql-devel postgresql-libs sqlite-devel libxslt-devel libxml2-devel patch openssl
gem install yajl-ruby

echo 'Dependencies installed.'

rm bosh-cli-6.4.5-linux-amd64
