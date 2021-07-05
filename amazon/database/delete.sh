#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '************'
echo 'Database box'
echo '************'
echo

db_endpoint="$(get_database_endpoint "${DB_NM}")"

if [[ -z "${db_endpoint}" ]]
then
   echo '* WARN: database box not found.'
else
   db_state="$(get_database_state "${DB_NM}")"
   echo "* database endpoint: "${db_endpoint}" (${db_state})."
fi

sgp_id="$(get_security_group_id "${DB_INST_SEC_GRP_NM}")"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: database security group not found.'
else
   echo "* database security group ID: ${sgp_id}."
fi

db_subnet_group_status="$(get_db_subnet_group_status "${DB_INST_SUBNET_GRP_NM}")"

if [[ -z "${db_subnet_group_status}" ]]
then
   echo '* WARN: database subnet group not found.'
else
   echo "* database subnet group status: ${db_subnet_group_status}."
fi

db_snapshot_ids="$(get_database_snapshot_ids "${DB_NM}")"

if [[ -z "${db_snapshot_ids}" ]]
then
   echo '* WARN: database snapshots not found'
else
   echo "* database snapshots identifiers: ${db_snapshot_ids}."
fi

echo

## 
## Database box
##
if [[ -n "${db_endpoint}" ]]
then
   db_state="$(get_database_state "${DB_NM}")"
   
   if [[ 'deleting' != "${db_state}" ]]
   then
      echo 'Deleting database box ...' 
        
      delete_database "${DB_INST_NM}"
      
      echo 'Database box deleted.'
   fi
fi

## 
## database snapshots
##

if [[ -n "${db_snapshot_ids}" ]]
then
   echo 'Deleting database snapshots ...'  
    
   for id in ${db_snapshot_ids}
   do
      delete_database_snapshot "${id}"
   done  
   
   echo 'Database snapshots deleted.'
fi

## 
## DB security group
## 
  
if [[ -n "${sgp_id}" ]]
then
   delete_security_group "${sgp_id}" 
      
   echo 'Database security group deleted.'
fi

## 
## database subnet group
## 

if [[ -n "${db_subnet_group_status}" ]]
then
   delete_db_subnet_group "${DB_INST_SUBNET_GRP_NM}"
   
   echo 'Database subnet group deleted.'
fi

##
## Parameter group
##

pg_exists="$(check_log_slow_queries_db_parameter_group_exists "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}")"

if [[ -n "${pg_exists}" ]]
then
   delete_log_slow_queries_db_parameter_group "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}"
   
   echo 'Log slow queries database parameter group deleted.'
   echo
fi

