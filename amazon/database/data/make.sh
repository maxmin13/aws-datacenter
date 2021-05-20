#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Uploads database files to the admin server,
# then runs the install script on the server

echo '*************'
echo 'Database data'
echo '*************'
echo

admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* ERROR: admin instance not found' 
   exit 1
else
   echo "* admin instance ID: '${admin_instance_id}'"
fi

adm_sgp_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -z "${adm_sgp_id}" ]]
then
   echo '* ERROR: admin security group not found'
   exit 1
else
   echo "* admin security group ID: '${adm_sgp_id}'"
fi

eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: admin public IP address not found'
   exit 1
else
   echo "* admin public IP address: '${eip}'"
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo '* ERROR: database endopoint not found'
   exit 1
else
   echo "* database endpoint: '${db_endpoint}'"
fi

echo

# Clear old files
rm -rf "${TMP_DIR:?}"/database
mkdir "${TMP_DIR}"/database

private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}")"

## Retrieve database scripts
sed "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    "${TEMPLATE_DIR}"/database/sql/dbs_template.sql > "${TMP_DIR}"/database/dbs.sql
    
echo 'dbs.sql ready'

sed -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    -e "s/SEDDBUSR_adminrwSED/${DB_MMDATA_ADMIN_USER_NM}/g" \
    -e "s/SEDDBPASS_adminrwSED/${DB_MMDATA_ADMIN_USER_PWD}/g" \
    -e "s/SEDDBUSR_webphprwSED/${DB_MMDATA_WEBPHP_USER_NM}/g" \
    -e "s/SEDDBPASS_webphprwSED/${DB_MMDATA_WEBPHP_USER_PWD}/g" \
    -e "s/SEDDBUSR_javamailSED/${DB_MMDATA_JAVAMAIL_USER_NM}/g" \
    -e "s/SEDDBPASS_javamailSED/${DB_MMDATA_JAVAMAIL_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/database/sql/dbusers_template.sql > "${TMP_DIR}"/database/dbusers.sql
       
echo 'dbusers.sql ready'    
    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_main_userSED/${DB_MMDATA_MAIN_USER_NM}/g" \
    -e "s/SEDdatabase_main_user_passwordSED/${DB_MMDATA_MAIN_USER_PWD}/g" \
    -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
       "${TEMPLATE_DIR}"/database/install_database_template.sh > "${TMP_DIR}"/database/install_database.sh  

echo 'install_database.sh ready' 

## ************
## SSH from dev
## ************

# Check if the Admin Security Group grants access from the development machine through SSH port
my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"

access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" '0.0.0.0/0')"
#####access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
   
if [[ -z "${access_granted}" ]]
then
   allow_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   ##### allow_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo "Granted SSH access to development machine" 
else
   echo 'SSH access already granted to development machine'    
fi

echo 'Waiting for SSH to start in the admin server'
wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

## **************
## Upload scripts
## **************

## 
## Remote commands that have to be executed as priviledged user are run with sudo.
## The ec2-user sudo command has been configured with password.
##  

remote_dir=/home/ec2-user/script

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir ${remote_dir}" \
                       "${private_key}" \
                       "${eip}" \
                       "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                       "${DEFAUT_AWS_USER}"

echo "Uploading database scripts ..."    
scp_upload_files       "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" "${remote_dir}" \
                       "${TMP_DIR}"/database/dbs.sql \
                       "${TMP_DIR}"/database/dbusers.sql \
                       "${TMP_DIR}"/database/install_database.sh            

echo "Creating Database ..."
 
# Run the install Database script uploaded in the Admin server. 
ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_database.sh" \
                       "${private_key}" \
                       "${eip}" \
                       "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                       "${DEFAUT_AWS_USER}" \
                       "${SERVER_ADMIN_EC2_USER_PWD}" 

ssh_run_remote_command_as_root "${remote_dir}/install_database.sh" \
                       "${private_key}" \
                       "${eip}" \
                       "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                       "${DEFAUT_AWS_USER}" \
                       "${SERVER_ADMIN_EC2_USER_PWD}"

# Clear remote home directory    
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
                       "${private_key}" \
                       "${eip}" \
                       "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                       "${DEFAUT_AWS_USER}"

echo 'Database created'

## 
## Remove SSH access to the admin server
## 

if [[ -n "${adm_sgp_id}" ]]
then
   revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
   #####revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access' 
fi

# Clear local files
rm -rf "${TMP_DIR:?}"/database

echo "Database created"

echo

