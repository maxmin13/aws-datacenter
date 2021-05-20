#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '************'
echo 'Database box'
echo '************'
echo

db_status="$(get_database_status "${DB_MMDATA_NM}")"

if [[ -z "${db_status}" ]]
then
   echo '* WARN: database instance not found'
else
   echo "* database status: '${db_status}'"
fi

sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"

if [[ -z "${sg_id}" ]]
then
   echo '* WARN: database security group not found'
else
   echo "* database security group ID: '${sg_id}'"
fi

db_subnet_group_status="$(get_db_subnet_group_status "${DB_MMDATA_SUB_GRP_NM}")"

if [[ -z "${db_subnet_group_status}" ]]
then
   echo '* WARN: database subnet group not found'
else
   echo "* database subnet group status: '${db_subnet_group_status}'"
fi

db_param_desc="$(get_db_parameter_group_desc "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}")"  

if [[ -z "${db_param_desc}" ]]
then
   echo '* WARN: slow queries log parameter group not found'
else
   echo "* slow queries log parameter group: '${db_param_desc}'"
fi

db_snapshot_ids="$(get_database_snapshot_ids "${DB_MMDATA_NM}")"

if [[ -z "${db_snapshot_ids}" ]]
then
   echo '* WARN: database snapshots not found'
else
   echo "* database snapshots identifiers: '${db_snapshot_ids}'"
fi

echo

## 
## Database instance
##
if [[ -n "${db_status}" ]]
then
   db_status="$(get_database_status "${DB_MMDATA_NM}")"
   if [[ 'deleting' != "${db_status}" ]]
   then
      echo 'Deleting database instance ...'   
      delete_database "${DB_MMDATA_INSTANCE_NM}"
      echo 'Database Instance deleted'
   fi
fi

## 
## Database snapshots
##

if [[ -n "${db_snapshot_ids}" ]]
then
   echo 'Deleting database snapshots ...'   
   for id in ${db_snapshot_ids}
   do
      delete_database_snapshot "${id}"
   done  
   echo 'Database snapshots deleted'
fi

## 
## DB Security Group
## 
  
if [[ -n "${sg_id}" ]]
then
   delete_security_group "${sg_id}"    
   echo 'Database security group deleted'
fi

## 
## Database Subnet Group
## 

if [[ -n "${db_subnet_group_status}" ]]
then
   delete_db_subnet_group "${DB_MMDATA_SUB_GRP_NM}"
   echo 'Database subnet group deleted'
fi

##
## Database Parameter Group
## 

if [[ -n "${db_param_desc}" ]]
then
   delete_db_parameter_group "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}"
   echo 'Slow queries log parameter group deleted'
fi

echo
