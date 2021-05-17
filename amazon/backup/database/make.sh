#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Uploads database files to the admin server,
# then runs the dump script on the server, enventually
# download the result of the dump from the server in the Download directory.

echo '***************'
echo 'Database backup'
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

eip="$(get_public_ip_address_associated_with_instance "${SERVER_ADMIN_NM}")"

if [[ -z "${eip}" ]]
then
   echo 'ERROR: Admin public IP address not found'
   exit 1
else
   echo "* Admin public IP address: '${eip}'"
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

echo 'Dumping database ...'

# Clear old files
rm -rf "${TMP_DIR:?}"/database
mkdir "${TMP_DIR}"/database

script_dir=/home/ec2-user/script
dump_dir=/home/ec2-user/dump
dump_file=dump-database-"$(date +"%d-%m-%Y-%H.%M"."%S")"
download_dir="${DOWNLOAD_DIR}"/database/"$(date +"%d-%m-%Y")"

if [[ ! -d "${download_dir}" ]]
then
   mkdir -p "${download_dir}"
fi

private_key="$(get_private_key_path "${SERVER_ADMIN_KEY_PAIR_NM}" "${ADMIN_ACCESS_DIR}")"
   
sed -e "s/SEDdatabase_hostSED/${db_endpoint}/g" \
    -e "s/SEDdatabase_main_userSED/${DB_MMDATA_MAIN_USER_NM}/g" \
    -e "s/SEDdatabase_main_user_passwordSED/${DB_MMDATA_MAIN_USER_PWD}/g" \
    -e "s/SEDdatabase_nameSED/${DB_MMDATA_NM}/g" \
    -e "s/SEDdump_dirSED/$(escape ${dump_dir})/g" \
    -e "s/SEDdump_fileSED/${dump_file}/g" \
       "${TEMPLATE_DIR}"/database/dump_database_template.sh > "${TMP_DIR}"/database/dump_database.sh  

echo 'dump_database.sh ready'

## ************
## SSH from dev
## ************

# Check if the Admin Security Group grants access from the development machine through SSH port
my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
##### TODO REMOVE THIS
access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0")"
#####access_granted="$(check_access_from_cidr_is_granted "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
   
if [[ -z "${access_granted}" ]]
then
   ##### TODO REMOVE THIS
   allow_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
   ##### allow_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo "Granted SSH access to development machine" 
else
   echo 'SSH access already granted to development machine'    
fi

echo 'Waiting for SSH to start'
wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

## **************
## Upload scripts
## **************

echo 'Uploading files to the Admin server ...'

ssh_run_remote_command "rm -rf ${script_dir} && rm -rf ${dump_dir} && mkdir ${script_dir} && mkdir ${dump_dir}" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"
                   
scp_upload_files "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" "${script_dir}" \
                   "${TMP_DIR}"/database/dump_database.sh             

echo "Dumping Database ..."
 
# Run the install Database script uploaded in the Admin server. 
ssh_run_remote_command_as_root "chmod +x ${script_dir}/dump_database.sh" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${SERVER_ADMIN_EC2_USER_PWD}" 

ssh_run_remote_command "${script_dir}/dump_database.sh" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"
                   
echo 'Database dumped, downloading the dump ...'                   

# Download the dump file.                   
scp_download_file  "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}" \
                   "${dump_dir}" \
                   "${dump_file}" \
                   "${download_dir}"    
                   
echo 'Database dump downloaded'

# Clear remote home directory    
ssh_run_remote_command "rm -rf ${script_dir:?} && rm -rf ${dump_dir:?}" \
                   "${private_key}" \
                   "${eip}" \
                   "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                   "${DEFAUT_AWS_USER}"               

## *****************
## Remove SSH access
## *****************

if [[ -z "${adm_sgp_id}" ]]
then
   echo "'${SERVER_ADMIN_SEC_GRP_NM}' Admin Security Group not found"
else
   ##### TODO REMOVE THIS
   revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
   #####revoke_access_from_cidr "${adm_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access' 
fi

# Clear local files
rm -rf "${TMP_DIR:?}"/database

echo "Database backup done"

echo

