#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# Install BOSH directory VM.
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change ownership in the script directory to delete it from dev machine.
trap "chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}" ERR EXIT

cd "${script_dir}" || exit



exit 0

