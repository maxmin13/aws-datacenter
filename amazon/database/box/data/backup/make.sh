#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##############################################################
# Uploads Database files to the Admin server,
# then runs the dump script on the server, 
# download the result of the dump in the Download directory.
##############################################################

database_dir='database'

echo '***************'
echo 'Database backup'
echo '***************'
echo

instance_id="$(get_instance_id "${SRV_ADMIN_NM}")"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Admin instance not found.' 
   exit 1
else
   echo "* Admin instance ID: ${instance_id}."
fi

sgp_id="$(get_security_group_id "${SRV_ADMIN_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: Admin Security Group not found.'
   exit 1
else
   echo "* Admin Security Group ID: ${sgp_id}."
fi

eip="$(get_public_ip_address_associated_with_instance "${SRV_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   exit 1
else
   echo "* Admin public IP address: ${eip}."
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

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

granted_ssh="$(check_access_from_cidr_is_granted  "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_ssh}" ]]
then
   echo 'WARN: SSH access to the Admin box already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${SHAR_INSTANCE_SSH_PORT}" '0.0.0.0/0'
   
   echo 'Granted SSH access to the Admin box.'
fi

echo 'Uploading database scripts to the Admin box ...'

remote_dir=/home/"${SRV_ADMIN_USER_NM}"/script
dump_dir=/home/"${SRV_ADMIN_USER_NM}"/dump
dump_file=dump-database-"$(date +"%d-%m-%Y-%H.%M"."%S")"
download_dir="${DOWNLOAD_DIR}"/"${database_dir}"/"$(date +"%d-%m-%Y")"

if [[ ! -d "${download_dir}" ]]
then
   mkdir -p "${download_dir}"
fi

key_pair_file="$(get_keypair_file_path "${SRV_ADMIN_KEY_PAIR_NM}" "${SRV_ADMIN_ACCESS_DIR}")"
wait_ssh_started "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}"

ssh_run_remote_command "rm -rf ${remote_dir} && rm -rf ${dump_dir} && mkdir ${remote_dir} && mkdir ${dump_dir}" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}"  

echo 'Uploading database scripts to the Admin box ...'
   
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_main_userSED/${DB_MMDATA_MAIN_USER_NM}/g" \
    -e "s/SEDdatabase_main_user_passwordSED/${DB_MMDATA_MAIN_USER_PWD}/g" \
    -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    -e "s/SEDdump_dirSED/$(escape ${dump_dir})/g" \
    -e "s/SEDdump_fileSED/${dump_file}/g" \
       "${TEMPLATE_DIR}"/database/dump_database_template.sh > "${TMP_DIR}"/"${database_dir}"/dump_database.sh  

echo 'dump_database.sh ready.'
                   
scp_upload_files "${key_pair_file}" "${eip}" "${SHAR_INSTANCE_SSH_PORT}" "${SRV_ADMIN_USER_NM}" "${remote_dir}" \
    "${TMP_DIR}"/"${database_dir}"/dump_database.sh             

echo 'Dumping Database ...'

# Run the install Database script uploaded in the Admin server. 
ssh_run_remote_command_as_root "chmod +x ${remote_dir}/dump_database.sh" \
    "${key_pair_file}" \
    "${eip}" \
    "${SHAR_INSTANCE_SSH_PORT}" \
    "${SRV_ADMIN_USER_NM}" \
    "${SRV_ADMIN_USER_PWD}" 
    
set +e   
          
ssh_run_remote_command_as_root "${remote_dir}/dump_database.sh" \
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
   echo 'Database successfully dumped.'

   # Download the dump file.                   
   scp_download_file "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}" \
       "${dump_dir}" \
       "${dump_file}" \
       "${download_dir}"    
                   
   echo 'Database dump downloaded.'
   echo "Check the directory: ${download_dir}"   
   
   ssh_run_remote_command "rm -rf ${remote_dir} && rm -rf ${dump_dir:?}" \
       "${key_pair_file}" \
       "${eip}" \
       "${SHAR_INSTANCE_SSH_PORT}" \
       "${SRV_ADMIN_USER_NM}"        
   
else
   echo 'ERROR: dumping database objects.'
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
    
# Removing temp files
rm -rf "${TMP_DIR:?}"/"${database_dir}" 
 
echo
echo "Database successfully dumped." 
echo

