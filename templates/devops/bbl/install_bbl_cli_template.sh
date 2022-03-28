#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BBL client and add it to the PATH.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
BBL_DOWNLOAD_URL='SEDbbl_download_urlSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

# Check if BOSH bootloader is already installed

set +e
bbl -v
exit_code=$?
set -e

if [[ 0 -eq "${exit_code}" ]]
then
   echo 'WARN: BOSH bootloader client already installed.'
   exit 0
fi

echo 'Installig BOSH bootloader client ...'

cd "${script_dir}" || exit
rm -rf temp
mkdir -p temp && cd temp || exit

wget "${BBL_DOWNLOAD_URL}"
file_name="$(ls)"
mv "${file_name}" /usr/bin/bbl
chmod 500 /usr/bin/bbl

bbl -v

echo 'BOSH bootloader client installed.'

exit 0

