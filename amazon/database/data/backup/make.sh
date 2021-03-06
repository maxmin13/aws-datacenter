#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##############################################################
# Uploads database files to the Admin server,
# then runs the dump script on the server, 
# download the result of the dump in the Download directory.
##############################################################

database_dir='database'

echo
echo '***************'
echo 'Database backup'
echo '***************'
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
   echo '* WARN: Admin security group not found.'
else
   echo "* Admin security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Admin public IP address not found.'
else
   echo "* Admin public IP address: ${eip}."
fi

get_database_endpoint "${DB_NM}"
db_endpoint="${__RESULT}"

if [[ -z "${db_endpoint}" ]]
then
   echo '* WARN: database endopoint not found.'
else
   echo "* database endpoint: ${db_endpoint}."
fi

echo

# Clear old files
rm -rf "${TMP_DIR:?}"/"${database_dir}"
mkdir "${TMP_DIR}"/"${database_dir}"

#
# Skip the backup if the database and the Admin box are not running.
#

if [[ -z "${instance_id}" ]]
then

   echo 'Admin box not found, skipping database backup.'

elif [[ 'running' != "${instance_st}" ]]
then

   echo 'Admin box not running, skipping database backup.'

elif [[ -n "${db_endpoint}" ]]
then

   ## 
   ## SSH Access 
   ## 

   # Check if the Admin box is SSH reacheable.
   set +e
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Granted SSH access to the Admin box.'

   echo 'Uploading database scripts to the Admin box ...'

   remote_dir=/home/"${ADMIN_INST_USER_NM}"/script
   dump_dir=/home/"${ADMIN_INST_USER_NM}"/dump
   dump_file=dump-database-"$(date +"%d-%m-%Y-%H.%M"."%S")"
   download_dir="${DOWNLOAD_DIR}"/"${database_dir}"/"$(date +"%d-%m-%Y")"

   if [[ ! -d "${download_dir}" ]]
   then
      mkdir -p "${download_dir}"
   fi

   private_key_file="${ADMIN_INST_ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 
   wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

   ssh_run_remote_command "rm -rf ${remote_dir} && rm -rf ${dump_dir} && mkdir ${remote_dir} && mkdir ${dump_dir}" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}"  

   echo 'Uploading database scripts to the Admin box ...'
   
   sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
       -e "s/SEDdatabase_main_userSED/${DB_MAIN_USER_NM}/g" \
       -e "s/SEDdatabase_main_user_passwordSED/${DB_MAIN_USER_PWD}/g" \
       -e "s/SEDdatabase_nameSED/${DB_NM}/g" \
       -e "s/SEDdump_dirSED/$(escape ${dump_dir})/g" \
       -e "s/SEDdump_fileSED/${dump_file}/g" \
          "${TEMPLATE_DIR}"/database/dump_database_template.sh > "${TMP_DIR}"/"${database_dir}"/dump_database.sh  

   echo 'dump_database.sh ready.'
                   
   scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
       "${TMP_DIR}"/"${database_dir}"/dump_database.sh             

   echo 'Dumping database ...'

   # Run the install database script uploaded in the Admin server. 
   ssh_run_remote_command_as_root "chmod +x ${remote_dir}/dump_database.sh" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${ADMIN_INST_USER_NM}" \
       "${ADMIN_INST_USER_PWD}" 
    
   set +e   
          
   ssh_run_remote_command_as_root "${remote_dir}/dump_database.sh" \
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
      echo 'Database successfully dumped.'

      # Download the dump file.                   
      scp_download_file "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${ADMIN_INST_USER_NM}" \
          "${dump_dir}" \
          "${download_dir}" \
          "${dump_file}" \
             
      echo 'Database dump downloaded.'
      echo "Check the directory: ${download_dir}"   
   
      ssh_run_remote_command "rm -rf ${remote_dir} && rm -rf ${dump_dir:?}" \
          "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${ADMIN_INST_USER_NM}"          
   else
      echo 'WARN: error dumping database objects.'
   fi
      
   ## 
   ## SSH Access.
   ## 

   set +e
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Revoked SSH access to the Admin box.' 
   
    
   # Removing temp files
   rm -rf "${TMP_DIR:?}"/"${database_dir}" 
fi


