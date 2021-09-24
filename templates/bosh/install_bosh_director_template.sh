#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

####################################################################
# BOSH (bosh outer shell) is a release-engineering tool chain that 
# provides an easy mechanism to version, package, and deploy 
# cloud based software: BOSH outer shell runs Clound Foundry so that
# Cloud Foundry can run your apps.
# BOSH supports deploying to multiple IaaS providers.
# BOSH focuses on defining your infrastructure as a piece of code.
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
# To use CLI:
#
#   bosh int ./creds.yml --path /admin_password
#   bosh envs
#   bosh login -e bosh_0 --client admin --client-secret <ADMIN-PWD>
#   bosh -h
# 
####################################################################

ADMIN_INST_USER_NM='SEDadmin_inst_user_nmSED'
DIRECTOR_INSTALL_DIR='SEDdirector_install_dirSED'
DIRECTOR_SSL_CERTIFICATE_NM='cacert.pem'
DIRECTOR_NM='SEDdirector_nmSED'
DIRECTOR_SEC_GRP_NM='SEDdirector_sec_grp_nmSED'
DIRECTOR_INTERNAL_IP='SEDdirector_internal_ipSED'
DIRECTOR_KEY_PAIR_NM='SEDdirector_key_pair_nmSED'
JUMPBOX_KEY_NM='jumpbox.key'

## Datacenter network configuration.
REGION='SEDregionSED'
GATEWAY_IP='SEDgateway_ipSED'
AZ1='SEDaz1SED'
MAIN_SUBNET_ID='SEDmain_subnet_idSED'
MAIN_SUBNET_CIDR='SEDmain_subnet_cidrSED'
MAIN_SUBNET_RESERVED_IPS='SEDmain_subnet_reserved_ipsSED'
AZ2='SEDaz2SED'
BACKUP_SUBNET_ID='SEDbackup_subnet_idSED'
BACKUP_SUBNET_CIDR='SEDbackup_subnet_cidrSED'

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
       -v region="${REGION}" \
       -v az="${AZ1}" \
       -v subnet_id="${MAIN_SUBNET_ID}" \
       -v internal_cidr="${MAIN_SUBNET_CIDR}" \
       -v internal_gw="${GATEWAY_IP}" \
       -v internal_ip="${DIRECTOR_INTERNAL_IP}" \
       -v director_name="${DIRECTOR_NM}" \
       -v default_key_name="${DIRECTOR_KEY_PAIR_NM}" \
       -v default_security_groups=["${DIRECTOR_SEC_GRP_NM}"] \
       --var-file private_key="${DIRECTOR_KEY_PAIR_NM}" \
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

mkdir -p "${DIRECTOR_INSTALL_DIR}"
cp set_director_passwd.yml vars.yml cloud.yml "${DIRECTOR_KEY_PAIR_NM}" "${DIRECTOR_INSTALL_DIR}"

cd "${DIRECTOR_INSTALL_DIR}" || exit

chmod 400 set_director_passwd.yml vars.yml cloud.yml "${DIRECTOR_KEY_PAIR_NM}"

if [[ ! -d 'bosh-deployment' ]]
then
  yum install -y git
  git clone https://github.com/cloudfoundry/bosh-deployment
  yum remove -y git
fi

echo 'Creating BOSH director ...'

# shellcheck disable=SC2015
create_director && echo 'BOSH director created.' ||
{
   echo 'Let''s wait a bit for IAM to be ready and try again (second time).'
   __wait 240  
   echo 'Let''s try now.' 
   create_director && echo 'BOSH director created.' ||
   {
      echo 'Let''s wait a bit for IAM to be ready and try again (third time).'
      __wait 240  
      echo 'Let''s try now.' 
      create_director && echo 'BOSH director created.' ||
      {
         echo 'Let''s wait a bit for IAM to be ready and try again (fourth time).'
         __wait 240  
         echo 'Let''s try now.' 
         create_director && echo 'BOSH director created.' ||
         {
            echo 'ERROR: creating BOSH director.'
            exit 1    
         }
      }   
   }
}

bosh int creds.yml --path /jumpbox_ssh/private_key > "${JUMPBOX_KEY_NM}"
bosh int creds.yml --path /director_ssl/ca > "${DIRECTOR_SSL_CERTIFICATE_NM}"
    
chmod 400 state.json creds.yml "${JUMPBOX_KEY_NM}" "${DIRECTOR_SSL_CERTIFICATE_NM}"

bosh_client='admin'
bosh_client_pwd="$(bosh int ./creds.yml --path /admin_password)"
bosh_cert="$(cat ${DIRECTOR_SSL_CERTIFICATE_NM})"

bosh alias-env "${DIRECTOR_NM}" -e "${DIRECTOR_INTERNAL_IP}" --ca-cert "${bosh_cert}"

echo 'BOSH alias created.' 

bosh login -e "${DIRECTOR_NM}" --client "${bosh_client}" --client-secret "${bosh_client_pwd}"

echo 'admin user logged into the Director.'

# Update cloud config.
bosh update-cloud-config cloud.yml \
    -e "${DIRECTOR_NM}" \
    -v internal_gw="${GATEWAY_IP}" \
    -v az1="${AZ1}" \
    -v main_subnet_id="${MAIN_SUBNET_ID}" \
    -v main_subnet_cidr="${MAIN_SUBNET_CIDR}" \
    -v main_subnet_reserved_ips="${MAIN_SUBNET_RESERVED_IPS}" \
    -v az2="${AZ2}" \
    -v backup_subnet_cidr="${BACKUP_SUBNET_CIDR}" \
    -v backup_subnet_id="${BACKUP_SUBNET_ID}" \
    --non-interactive
    
echo 'BOSH nework cloud configuration updated.'    

bosh -e "${DIRECTOR_NM}" cloud-config
    
bosh logout -e "${DIRECTOR_NM}"

echo 'admin user logged out from the Director.'
echo 'BOSH director successfully installed.'

echo
echo "cd ${DIRECTOR_INSTALL_DIR}"
echo "rm -f /root/.ssh/known_hosts && ssh jumpbox@${DIRECTOR_INTERNAL_IP} -i ${JUMPBOX_KEY_NM}"
    
exit 0

