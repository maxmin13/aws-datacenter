#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# BOSH (bosh outer shell) is a release-engineering tool chain that 
# provides an easy mechanism to version, package, and deploy 
# cloud based software: BOSH outer shell runs Clound Foundry so that
# Cloud Foundry can run you apps.
# BOSH supports deploying to multiple IaaS providers.
# BOSH focuses on defining your infrastructure as a piece of code.
# A single BOSH environment consists of the Director VM and any 
# deployments it orchestrates.
#
# stemcell: hardened and versioned base OS image wrapped with
#           minimal IaaS-specific packaging. It contains A BOSH 
#           agent for communication back to the Director. All
#           machines created by BOSH are created from stemcells.
#
# releases: A BOSH release is your software, including all 
#           configuration and dependencies required to build and  
#           run your software in a reproducible way.
#
# deployments: a collection of one or more machines (VMs). Machines
#           are built from stemcells and then layered and 
#           configured with specified components from one or more 
#           BOSH releases.
#
# The script deploys a VM with BOSH director installed and running.
# To debug any error during the director's installation:
#  
#   bosh -e bosh_0 task <TASK_NUMBER> --debug 
# 
# To connect to the director VM, from the Admin box:
#  
#   cd /opt/bosh
#   ssh jumpbox@10.0.0.6 -i jumpbox.key
# 
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
BOSH_DIRECTOR_INSTALL_DIR='SEDbosh_director_install_dirSED'
BOSH_DIRECTOR_SSL_CERTIFICATE_NM='cacert.pem'
BOSH_GATEWAY_IP='SEDbosh_gateway_ipSED'
BOSH_DIRECTOR_NM='SEDbosh_director_nmSED'
BOSH_CIDR='SEDbosh_cidrSED'
BOSH_REGION='SEDbosh_regionSED'
BOSH_AZ='SEDbosh_azSED'
BOSH_SUBNET_ID='SEDbosh_subnet_idSED'
BOSH_SEC_GROUP_NM='SEDbosh_sec_group_nmSED'
BOSH_INTERNAL_IP='SEDbosh_internal_ipSED'
BOSH_KEY_PAIR_NM='SEDbosh_key_pair_nmSED'
BOSH_LOG_LEVEL='debug'
JUMPBOX_KEY_NM='jumpbox.key'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function create_director()
{
   local exit_code=0
   
   bosh create-env bosh-deployment/bosh.yml \
       --state=state.json \
       --vars-store=creds.yml \
       -o bosh-deployment/aws/cpi.yml \
       -o bosh-deployment/aws/iam-instance-profile.yml \
       -o bosh-deployment/aws/cli-iam-instance-profile.yml \
       -o bosh-deployment/jumpbox-user.yml \
       -o set_director_passwd.yml \
       -v director_name="${BOSH_DIRECTOR_NM}" \
       -v subnet_id="${BOSH_SUBNET_ID}" \
       -v internal_cidr="${BOSH_CIDR}" \
       -v internal_gw="${BOSH_GATEWAY_IP}" \
       -v internal_ip="${BOSH_INTERNAL_IP}" \
       -v region="${BOSH_REGION}" \
       -v az="${BOSH_AZ}" \
       -v default_key_name="${BOSH_KEY_PAIR_NM}" \
       -v default_security_groups=["${BOSH_SEC_GROUP_NM}"] \
       --var-file private_key="${BOSH_KEY_PAIR_NM}" \
       --vars-file vars.yml
       
    exit_code=$?
    
    if [[ 0 -ne "${exit_code}" ]]
    then
       echo 'ERROR: creating BOSH director.'
    fi
    
    return "${exit_code}"
}


function __wait()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local seconds="${1}"
   local count=0
   
   while [[ "${count}" -lt "${seconds}" ]]; do
      printf '.'
      sleep 1
      count=$((count+1))
   done
   
   printf '\n'

   return 0
}

# Change ownership in the script directory to delete it from dev machine.
trap 'chown -R ${ADMIN_INST_USER_NM}:${ADMIN_INST_USER_NM} ${script_dir}' ERR EXIT

cd "${script_dir}" || exit

mkdir -p "${BOSH_DIRECTOR_INSTALL_DIR}"
cp set_director_passwd.yml vars.yml "${BOSH_KEY_PAIR_NM}" "${BOSH_DIRECTOR_INSTALL_DIR}"

cd "${BOSH_DIRECTOR_INSTALL_DIR}" || exit

chmod 400 set_director_passwd.yml vars.yml "${BOSH_KEY_PAIR_NM}"

yum install -y git
git clone https://github.com/cloudfoundry/bosh-deployment
yum remove -y git

echo 'Creating BOSH director ...'

create_director && echo 'BOSH director created.' ||
{
   echo 'Let''s wait a bit for IAM to be ready and try again (second time).'
   __wait 180  
   echo 'Let''s try now.' 
   create_director && echo 'BOSH director created.' ||
   {
      echo 'ERROR: creating BOSH director.'
      exit 1    
   }
}

bosh int creds.yml --path /jumpbox_ssh/private_key > "${JUMPBOX_KEY_NM}"
bosh int creds.yml --path /director_ssl/ca > "${BOSH_DIRECTOR_SSL_CERTIFICATE_NM}"
    
chmod 400 state.json creds.yml "${JUMPBOX_KEY_NM}" "${BOSH_DIRECTOR_SSL_CERTIFICATE_NM}"

bosh_client='admin'
bosh_client_pwd="$(bosh int ./creds.yml --path /admin_password)"
bosh login -e "${BOSH_DIRECTOR_NM}" --client "${bosh_client}" --client-secret "${bosh_client_pwd}"
echo 'admin user logged in.' 

bosh_cert="$(cat ${BOSH_DIRECTOR_SSL_CERTIFICATE_NM})"
bosh alias-env "${BOSH_DIRECTOR_NM}" -e "${BOSH_INTERNAL_IP}" --ca-cert "${bosh_cert}"
echo 'BOSH alias created.' 

# Set basic cloud config.
bosh update-cloud-config bosh-deployment/aws/cloud-config.yml \
    -e "${BOSH_DIRECTOR_NM}" \
    -v az="${BOSH_AZ}" \
    -v internal_cidr="${BOSH_CIDR}" \
    -v internal_gw="${BOSH_GATEWAY_IP}" \
    -v subnet_id="${BOSH_SUBNET_ID}" \
    --non-interactive
    
echo 'BOSH basic cloud configuration set.'    
    
# Show deployments (should be empty).
bosh -e "${BOSH_DIRECTOR_NM}" deployments

# Show vms (should be empty)
bosh -e "${BOSH_DIRECTOR_NM}" vms

bosh logout -e "${BOSH_DIRECTOR_NM}"

echo 'admin user logged out.'
echo 'BOSH director successfully installed.'

echo
echo "cd ${BOSH_DIRECTOR_INSTALL_DIR}"
echo "rm -f /root/.ssh/known_hosts && ssh jumpbox@${BOSH_INTERNAL_IP} -i ${JUMPBOX_KEY_NM}"
    
exit 0

