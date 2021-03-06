#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Uploads database files to the Admin server and runs them.

database_dir='database'

echo
echo '****************'
echo 'Database objects'
echo '****************'
echo

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   exit 1
else
   echo "* Admin public IP address: ${eip}."
fi

get_database_endpoint "${DB_NM}"
db_endpoint="${__RESULT}"

if [[ -z "${db_endpoint}" ]]
then
   echo '* ERROR: database endopoint not found.'
   exit 1
else
   echo "* database endpoint: ${db_endpoint}."
fi

echo

# Clear old files
rm -rf "${TMP_DIR:?}"/"${database_dir}"
mkdir "${TMP_DIR}"/"${database_dir}"

## 
## SSH Access 
## 

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access to the Admin box.'

echo 'Uploading database scripts to the Admin box ...'

remote_dir=/home/"${ADMIN_INST_USER_NM}"/script

private_key_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}"  

sed "s/SEDdatabase_nameSED/${DB_NM}/g" \
    "${TEMPLATE_DIR}"/database/sql/dbs_template.sql > "${TMP_DIR}"/"${database_dir}"/dbs.sql
    
echo 'dbs.sql ready.'

sed -e "s/SEDdatabase_nameSED/${DB_NM}/g" \
    -e "s/SEDDBUSR_adminrwSED/${DB_ADMIN_USER_NM}/g" \
    -e "s/SEDDBPASS_adminrwSED/${DB_ADMIN_USER_PWD}/g" \
    -e "s/SEDDBUSR_webphprwSED/${DB_WEBPHP_USER_NM}/g" \
    -e "s/SEDDBPASS_webphprwSED/${DB_WEBPHP_USER_PWD}/g" \
    -e "s/SEDDBUSR_javamailSED/${DB_JAVAMAIL_USER_NM}/g" \
    -e "s/SEDDBPASS_javamailSED/${DB_JAVAMAIL_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/database/sql/dbusers_template.sql > "${TMP_DIR}"/"${database_dir}"/dbusers.sql
       
echo 'dbusers.sql ready.'    
    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_main_userSED/${DB_MAIN_USER_NM}/g" \
    -e "s/SEDdatabase_main_user_passwordSED/${DB_MAIN_USER_PWD}/g" \
    -e "s/SEDdatabase_nameSED/${DB_NM}/g" \
       "${TEMPLATE_DIR}"/database/install_database_template.sh > "${TMP_DIR}"/"${database_dir}"/install_database.sh  

echo 'install_database.sh ready.' 

echo "Uploading database scripts ..."    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${database_dir}"/dbs.sql \
    "${TMP_DIR}"/"${database_dir}"/dbusers.sql \
    "${TMP_DIR}"/"${database_dir}"/install_database.sh     
       
echo 'Scripts uploaded.'
echo "Installing database objects ..."
 
# Run the install database script uploaded in the Admin server. 
ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_database.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}" 
    
set +e   
          
ssh_run_remote_command_as_root "${remote_dir}/install_database.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}"   
                     
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 0 -eq "${exit_code}" ]
then
   echo 'Database objects successfully installed.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"     
else
   echo 'ERROR: installing database objects.'
   exit 1
fi
      
## 
## SSH Access.
## 

# Revoke SSH access from the development machine
set +e
revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Admin box.' 
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${database_dir}" 
 
echo
echo "Database box up and running at ${db_endpoint}." 


