#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Uploads database files to the Admin server and runs them.

database_dir='database'

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
   instance_st="$(get_instance_state "${ADMIN_INST_NM}")"
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

sgp_id="$(get_security_group_id "${ADMIN_INST_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   exit 1
else
   echo "* Admin public IP address: ${eip}."
fi

db_endpoint="$(get_database_endpoint "${DB_NM}")"

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

granted_ssh="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0')"

if [[ -n "${granted_ssh}" ]]
then
   echo 'WARN: SSH access to the Admin box already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   
   echo 'Granted SSH access to the Admin box.'
fi

echo 'Uploading database scripts to the Admin box ...'

remote_dir=/home/"${ADMIN_INST_USER_NM}"/script

key_pair_file="$(get_keypair_file_path "${ADMIN_INST_KEY_PAIR_NM}" "${ADMIN_INST_ACCESS_DIR}")"
wait_ssh_started "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}"  

sed "s/SEDdatabase_nameSED/${DB_NM}/g" \
    "${TEMPLATE_DIR}"/"${database_dir}"/sql/dbs_template.sql > "${TMP_DIR}"/"${database_dir}"/dbs.sql
    
echo 'dbs.sql ready.'

sed -e "s/SEDdatabase_nameSED/${DB_NM}/g" \
    -e "s/SEDDBUSR_adminrwSED/${DB_ADMIN_USER_NM}/g" \
    -e "s/SEDDBPASS_adminrwSED/${DB_ADMIN_USER_PWD}/g" \
    -e "s/SEDDBUSR_webphprwSED/${DB_WEBPHP_USER_NM}/g" \
    -e "s/SEDDBPASS_webphprwSED/${DB_WEBPHP_USER_PWD}/g" \
    -e "s/SEDDBUSR_javamailSED/${DB_JAVAMAIL_USER_NM}/g" \
    -e "s/SEDDBPASS_javamailSED/${DB_JAVAMAIL_USER_PWD}/g" \
       "${TEMPLATE_DIR}"/"${database_dir}"/sql/dbusers_template.sql > "${TMP_DIR}"/"${database_dir}"/dbusers.sql
       
echo 'dbusers.sql ready.'    
    
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_main_userSED/${DB_MAIN_USER_NM}/g" \
    -e "s/SEDdatabase_main_user_passwordSED/${DB_MAIN_USER_PWD}/g" \
    -e "s/SEDdatabase_nameSED/${DB_NM}/g" \
       "${TEMPLATE_DIR}"/"${database_dir}"/install_database_template.sh > "${TMP_DIR}"/"${database_dir}"/install_database.sh  

echo 'install_database.sh ready.' 

echo "Uploading database scripts ..."    
scp_upload_files "${key_pair_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${ADMIN_INST_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${database_dir}"/dbs.sql \
    "${TMP_DIR}"/"${database_dir}"/dbusers.sql \
    "${TMP_DIR}"/"${database_dir}"/install_database.sh     
       
echo 'Scripts uploaded.'
echo "Installing database objects ..."
 
# Run the install database script uploaded in the Admin server. 
ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_database.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${ADMIN_INST_USER_NM}" \
    "${ADMIN_INST_USER_PWD}" 
    
set +e   
          
ssh_run_remote_command_as_root "${remote_dir}/install_database.sh" \
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
   echo 'Database objects successfully installed.'
   
   ssh_run_remote_command "rm -rf ${remote_dir}" \
       "${key_pair_file}" \
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

if [[ -n "${sgp_id}" ]]
then
   # Revoke SSH access from the development machine
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   
   echo 'Revoked SSH access to the Admin box.' 
fi
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${database_dir}" 
 
echo
echo "Database box up and running at ${db_endpoint}." 
echo

