#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Uploads database files to the admin server
# then runs the delete script on the server

database_dir='database'

echo '****************'
echo 'Database objects'
echo '****************'
echo

# Clear old files
rm -rf "${TMP_DIR:?}"/"${database_dir}"
mkdir "${TMP_DIR}"/"${database_dir}"

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
   echo '* WARN: admin security group not found.'
else
   echo "* Admin security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Admin public address not found.'
else
   echo "* Admin public address: ${eip}."
fi

db_endpoint="$(get_database_endpoint "${DB_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo '* WARN: database endpoint not found'
else
   echo "* database endpoint: ${db_endpoint}."
fi

echo

if [[ -z "${db_endpoint}" ]]
then

   echo 'Database box not found, skipping deleting database data.'

elif [[ -z "${instance_id}" ]]
then

   echo 'Admin box not found, skipping deleting database data.'

elif [[ 'running' != "${instance_st}" ]]
then

   echo 'Admin box not running, skipping deleting database data.'
else

   ## Retrieve database scripts
   sed "s/SEDdatabase_nameSED/${DB_NM}/g" \
       "${TEMPLATE_DIR}"/database/sql/delete_dbs_template.sql > "${TMP_DIR}"/"${database_dir}"/delete_dbs.sql

   sed -e "s/SEDdatabase_nameSED/${DB_NM}/g" \
       -e "s/SEDDBUSR_adminrwSED/${DB_ADMIN_USER_NM}/g" \
       -e "s/SEDDBPASS_adminrwSED/${DB_ADMIN_USER_PWD}/g" \
       -e "s/SEDDBUSR_webphprwSED/${DB_WEBPHP_USER_NM}/g" \
       -e "s/SEDDBPASS_webphprwSED/${DB_WEBPHP_USER_PWD}/g" \
       -e "s/SEDDBUSR_javamailSED/${DB_JAVAMAIL_USER_NM}/g" \
       -e "s/SEDDBPASS_javamailSED/${DB_JAVAMAIL_USER_PWD}/g" \
          "${TEMPLATE_DIR}"/database/sql/delete_dbusers_template.sql > "${TMP_DIR}"/"${database_dir}"/delete_dbusers.sql
    
   sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
       -e "s/SEDdatabase_main_userSED/${DB_MAIN_USER_NM}/g" \
       -e "s/SEDdatabase_main_user_passwordSED/${DB_MAIN_USER_PWD}/g" \
          "${TEMPLATE_DIR}"/database/delete_database_template.sh > "${TMP_DIR}"/"${database_dir}"/delete_database.sh   

   ## SSH access 
  
   # Check if the Admin security group grants access from the development machine through SSH port
   set +e
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Granted SSH access to development machine.'

   echo 'Uploading database scripts to the Admin box ...'
   
   remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
   key_pair_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 
   wait_ssh_started "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"
  
   ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir ${remote_dir}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"
                   
   scp_upload_files "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/database/delete_dbs.sql \
       "${TMP_DIR}"/database/delete_dbusers.sql \
       "${TMP_DIR}"/database/delete_database.sh

   echo "Deleting database objects ..."
   
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_database.sh" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"    
 
   set +e   
          
   ssh_run_remote_command_as_root "${remote_dir}/delete_database.sh" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}"   
                     
   exit_code=$?
   set -e

   # shellcheck disable=SC2181
   if [ 0 -eq "${exit_code}" ]
   then
      echo 'Database objects successfully deleted.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"     
   else
      echo 'ERROR: deleting database objects.'
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
     
  # Clear local data
  rm -rf "${TMP_DIR:?}"/"${database_dir}"

  echo 'Database objects deleted.'    

fi

echo

