#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo
echo '************'
echo 'Database box'
echo '************'
echo

get_database_endpoint "${DB_NM}"
db_endpoint="${__RESULT}"

if [[ -z "${db_endpoint}" ]]
then
   echo '* WARN: database box not found.'
else
   get_database_state "${DB_NM}"
   db_state="${__RESULT}"
   
   echo "* database endpoint: "${db_endpoint}" (${db_state})."
fi

get_security_group_id "${DB_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: database security group not found.'
else
   echo "* database security group ID: ${sgp_id}."
fi

get_db_subnet_group_status "${DB_INST_SUBNET_GRP_NM}"
db_subnet_group_status="${__RESULT}"

if [[ -z "${db_subnet_group_status}" ]]
then
   echo '* WARN: database subnet group not found.'
else
   echo "* database subnet group status: ${db_subnet_group_status}."
fi

get_database_snapshot_ids "${DB_NM}"
db_snapshot_ids="${__RESULT}"

if [[ -z "${db_snapshot_ids}" ]]
then
   echo '* WARN: database snapshots not found.'
else
   echo "* database snapshots identifiers: ${db_snapshot_ids}."
fi

echo

## 
## Database box
##
if [[ -n "${db_endpoint}" ]]
then
   get_database_state "${DB_NM}"
   db_state="${__RESULT}"
   
   if [[ 'deleting' != "${db_state}" ]]
   then
      echo 'Deleting database box ...' 
        
      delete_database "${DB_INST_NM}"
      
      echo 'Database box deleted.'
   fi
fi

## 
## Snapshots
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
## Security group
## 
  
if [[ -n "${sgp_id}" ]]
then
   delete_security_group "${sgp_id}" 
      
   echo 'Database security group deleted.'
fi

## 
## Subnet group
## 

if [[ -n "${db_subnet_group_status}" ]]
then
   delete_db_subnet_group "${DB_INST_SUBNET_GRP_NM}"
   
   echo 'Database subnet group deleted.'
fi

##
## Parameter group
##

check_db_parameter_group_exists "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}"
pg_exists="${__RESULT}"
   
if [[ 'true' == "${pg_exists}" ]]
then
   delete_log_slow_queries_db_parameter_group "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}"
   
   echo 'Log slow queries database parameter group deleted.'
fi

