#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo 'Creating BOSH director with override ...' 

bosh create-env \
  ${BBL_STATE_DIR}/bosh-deployment/bosh.yml \
  --state  ${BBL_STATE_DIR}/vars/bosh-state.json \
  --vars-store  ${BBL_STATE_DIR}/vars/director-vars-store.yml \
  --vars-file  ${BBL_STATE_DIR}/director_vars.yml \
  --vars-file  ${BBL_STATE_DIR}/vars/director-vars-file.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/aws/cpi.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/jumpbox-user.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/uaa.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/credhub.yml \
  -o  ${BBL_STATE_DIR}/bbl-ops-files/aws/bosh-director-ephemeral-ip-ops.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/aws/iam-instance-profile.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/aws/cli-iam-instance-profile.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/aws/encrypted-disk.yml \
  -o  ${BBL_STATE_DIR}/enable_debug.yml 
  
echo 'BOSH director with override created.'
