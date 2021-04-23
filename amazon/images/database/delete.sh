#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '*****************'
echo 'Database instance'
echo '*****************'
echo

echo 'Deleting Database components ...'

db_status="$(get_database_status "${DB_MMDATA_NM}")"

if [[ -n "${db_status}" ]]
then
   echo "'${DB_MMDATA_INSTANCE_NM}' Database Instance status: '${db_status}'"

   if [[ deleting != "${db_status}" ]]
   then
      echo "Deleting '${DB_MMDATA_INSTANCE_NM}' Database Instance ..."   
      delete_database "${DB_MMDATA_INSTANCE_NM}"
      echo "'${DB_MMDATA_INSTANCE_NM}' Database Instance deleted"
   fi
else
   echo "'${DB_MMDATA_INSTANCE_NM}' Database Instance not found"
fi

## ******************
## Database snapshots
## ******************

db_snapshot_ids="$(get_database_snapshot_ids "${DB_MMDATA_NM}")"

if [[ -n "${db_snapshot_ids}" ]]
then
   echo "Deleting '${db_snapshot_ids}' Database Snapshots ..."
   
   for id in ${db_snapshot_ids}
   do
      delete_database_snapshot "${id}"
   done
  
   echo 'Image snapshots deleted'
else
   echo 'Database Snapshots not found' 
fi

## *****************
## DB Security Group
## *****************
  
sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"
  
if [[ -z "${sg_id}" ]]
then
   echo "'${DB_MMDATA_SEC_GRP_NM}' Security Group not found"
else
   delete_security_group "${sg_id}"    
   echo "'${DB_MMDATA_SEC_GRP_NM}' Security Group deleted"
fi

## *********************
## Database Subnet Group
## *********************

dbsubnetg_sts="$(get_db_subnet_group_status "${DB_MMDATA_SUB_GRP_NM}")"
  
if [[ -z "${dbsubnetg_sts}" ]]
then
   echo "'${DB_MMDATA_SUB_GRP_NM}' DB Subnet Group not found"
else
   delete_db_subnet_group "${DB_MMDATA_SUB_GRP_NM}"
   echo "'${DB_MMDATA_SUB_GRP_NM}' DB Subnet Group deleted"
fi

## ************************
## Database Parameter Group
## ************************

param_desc="$(get_db_parameter_group_desc "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}")"  

if [[ -z "${param_desc}" ]]
then
   echo "'${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}' DB Parameter Group not found"
else
   delete_db_parameter_group "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}"
   echo "'${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}' DB parameter group deleted"
fi

echo 'Database components deleted'
echo
