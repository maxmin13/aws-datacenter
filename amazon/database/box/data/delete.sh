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

instance_id="$(get_instance_id "${SRV_ADMIN_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   instance_st="$(get_instance_state "${SRV_ADMIN_NM}")"
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

sgp_id="$(get_security_group_id "${SRV_ADMIN_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: admin security group not found.'
else
   echo "* Admin security group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${SRV_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Admin public address not found.'
else
   echo "* Admin public address: ${eip}."
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

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
   sed "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
       "${TEMPLATE_DIR}"/database/sql/delete_dbs_template.sql > "${TMP_DIR}"/"${database_dir}"/delete_dbs.sql

   sed -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
       -e "s/SEDDBUSR_adminrwSED/${DB_MMDATA_ADMIN_USER_NM}/g" \
       -e "s/SEDDBPASS_adminrwSED/${DB_MMDATA_ADMIN_USER_PWD}/g" \
       -e "s/SEDDBUSR_webphprwSED/${DB_MMDATA_WEBPHP_USER_NM}/g" \
       -e "s/SEDDBPASS_webphprwSED/${DB_MMDATA_WEBPHP_USER_PWD}/g" \
       -e "s/SEDDBUSR_javamailSED/${DB_MMDATA_JAVAMAIL_USER_NM}/g" \
       -e "s/SEDDBPASS_javamailSED/${DB_MMDATA_JAVAMAIL_USER_PWD}/g" \
          "${TEMPLATE_DIR}"/database/sql/delete_dbusers_template.sql > "${TMP_DIR}"/"${database_dir}"/delete_dbusers.sql
    
   sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
       -e "s/SEDdatabase_main_userSED/${DB_MMDATA_MAIN_USER_NM}/g" \
       -e "s/SEDdatabase_main_user_passwordSED/${DB_MMDATA_MAIN_USER_PWD}/g" \
          "${TEMPLATE_DIR}"/database/delete_database_template.sh > "${TMP_DIR}"/"${database_dir}"/delete_database.sh   

   ## SSH access 
  
   # Check if the Admin security group grants access from the development machine through SSH port
   access_granted="$(check_access_from_cidr_is_granted "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"
   
   if [[ -z "${access_granted}" ]]
   then
      allow_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'

      echo 'Granted SSH access to development machine.' 
   else
      echo 'SSH access already granted to development machine.'    
   fi

   echo 'Uploading database scripts to the Admin box ...'
   
   remote_dir=/home/"${SRV_ADMIN_USER_NM}"/script
   key_pair_file="$(get_keypair_file_path "${SRV_ADMIN_KEY_PAIR_NM}" "${SRV_ADMIN_ACCESS_DIR}")"
   wait_ssh_started "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}"
  
   ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir ${remote_dir}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}"
                   
   scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/database/delete_dbs.sql \
       "${TMP_DIR}"/database/delete_dbusers.sql \
       "${TMP_DIR}"/database/delete_database.sh

   echo "Deleting database objects ..."
   
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/delete_database.sh" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}" \
       "${SRV_ADMIN_USER_PWD}"    
 
   set +e   
          
   ssh_run_remote_command_as_root "${remote_dir}/delete_database.sh" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}" \
       "${SRV_ADMIN_USER_PWD}"   
                     
   exit_code=$?
   set -e

   # shellcheck disable=SC2181
   if [ 0 -eq "${exit_code}" ]
   then
      echo 'Database objects successfully deleted.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}"     
   else
      echo 'ERROR: deleting database objects.'
      exit 1
   fi       
   
   ## 
   ## SSH Access.
   ## 

   if [[ -n "${sgp_id}" ]]
   then
      # Revoke SSH access from the development machine
      revoke_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
    
      echo 'Revoked SSH access to the Admin box.' 
  fi
     
  # Clear local data
  rm -rf "${TMP_DIR:?}"/"${database_dir}"

  echo 'Database objects deleted.'    

fi

echo

