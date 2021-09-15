#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Remove BOSH client.
####################################################################

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${script_dir}" || exit

echo 'Removing Bosh client ...'

rm -f /usr/bin/bosh

echo 'Bosh client removed.'

bosh -v

yum remove -y gcc gcc-c++ ruby ruby-devel mysql-devel postgresql-devel postgresql-libs sqlite-devel libxslt-devel libxml2-devel patch openssl

echo 'Dependencies removed.'

exit 0

