#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Uploads database files to the admin server,
# then runs the install script on the server

echo '***************'
echo 'Database deploy'
echo '***************'
echo

admin_instance_id="$(get_instance_id "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_instance_id}" ]]
then
   echo "Error: Instance '${SERVER_ADMIN_NM}' not found"
   exit 1
else
   echo "* Admin instance ID: '${admin_instance_id}'"
fi

adm_sgp_id="$(get_security_group_id "${SERVER_ADMIN_SEC_GRP_NM}")"

if [[ -z "${adm_sgp_id}" ]]
then
   echo 'ERROR: The Admin security group not found'
   exit 1
else
   echo "* Admin Security Group ID: '${adm_sgp_id}'"
fi

admin_eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${admin_eip}" ]]
then
   echo 'ERROR: Admin public IP address not found'
   exit 1
else
   echo "* Admin public IP address: '${admin_eip}'"
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo 'ERROR: Database endopoint not found'
   exit 1
else
   echo "* Database endpoint: '${db_endpoint}'"
fi

echo

# Clear old files
rm -rf "${TMP_DIR:?}"/database
mkdir "${TMP_DIR}"/database

private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}")"

## Retrieve database scripts
sed "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    "${TEMPLATE_DIR}"/database/sql/dbs_template.sql > "${TMP_DIR}"/database/dbs.sql

sed -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    -e "s/SEDDBUSR_adminrwSED/${DB_MMDATA_ADMIN_USER_NM}/g" \
    -e "s/SEDDBPASS_adminrwSED/${DB_MMDATA_ADMIN_USER_PWD}/g" \
    -e "s/SEDDBUSR_webphprwSED/${DB_MMDATA_WEBPHP_USER_NM}/g" \
    -e "s/SEDDBPASS_webphprwSED/${DB_MMDATA_WEBPHP_USER_PWD}/g" \
    -e "s/SEDDBUSR_javamailSED/${DB_MMDATA_JAVAMAIL_USER_NM}/g" \
    -e "s/SEDDBPASS_javamailSED/${DB_MMDATA_JAVAMAIL_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/database/sql/dbusers_template.sql > "${TMP_DIR}"/database/dbusers.sql
    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_main_userSED/${DB_MMDATA_MAIN_USER_NM}/g" \
    -e "s/SEDdatabase_main_user_passwordSED/${DB_MMDATA_MAIN_USER_PWD}/g" \
    -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
       "${TEMPLATE_DIR}"/database/install_database_template.sh > "${TMP_DIR}"/database/install_database.sh  

## ************
## SSH from dev
## ************

# Check if the Admin Security Group grants access from the development machine through SSH port
my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
   
if [[ -z "${access_granted}" ]]
then
   allow_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo "Granted SSH access to development machine" 
else
   echo 'SSH access already granted to development machine'    
fi

echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${admin_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

## **************
## Upload scripts
## **************

echo "Uploading Database scripts ..."    
scp_upload_files "${private_key}" "${admin_eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" \
                 "${TMP_DIR}"/database/dbs.sql \
                 "${TMP_DIR}"/database/dbusers.sql \
                 "${TMP_DIR}"/database/install_database.sh            

echo "Creating Database ..."
 
# Run the install Database script uploaded in the Admin server. 
ssh_run_remote_command 'chmod +x install_database.sh' \
                   "${private_key}" \
                   "${admin_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}" 

ssh_run_remote_command './install_database.sh' \
                   "${private_key}" \
                   "${admin_eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}"

# Clear remote home directory
ssh_run_remote_command 'rm -f -R /home/ec2-user/*' \
                    "${private_key}" \
                    "${admin_eip}" \
                    "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                    "${DEFAUT_AWS_USER}" \
                    "${SERVER_ADMIN_EC2_USER_PWD}"

echo 'Database created'

## *****************
## Remove SSH access
## *****************

if [[ -z "${adm_sgp_id}" ]]
then
   echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group not found"
else
   revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access' 
fi

# Clear local files
rm -rf "${TMP_DIR:?}"/database

echo "Database created"

echo

