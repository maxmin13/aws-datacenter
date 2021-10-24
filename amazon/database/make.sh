#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## database schema, tables, data are created with the deploy database script.

echo
echo '************'
echo 'Database box'
echo '************'
echo

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"

if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_ids "${dtc_id}"
subnet_ids="${__RESULT}"

if [[ -z "${subnet_ids}" ]]
then
   echo '* ERROR: subnets not found.'
   exit 1
else
   echo "* subnet IDs: ${subnet_ids}."
fi

echo

## 
## Security group
##

get_security_group_id "${DB_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"
  
if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the database security group is already created.'
else
   create_security_group "${dtc_id}" "${DB_INST_SEC_GRP_NM}" 'Database security group.'
   get_security_group_id "${DB_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"

   echo 'Database security group created.'
fi

## 
## Subnet group.
## 

get_db_subnet_group_status "${DB_INST_SUBNET_GRP_NM}"
db_subnet_group_status="${__RESULT}"

if [[ -n "${db_subnet_group_status}" ]]
then
   echo 'WARN: the database subnet group is already created.'
else 
   create_db_subnet_group "${DB_INST_SUBNET_GRP_NM}" "${DB_INST_SUBNET_GRP_DESC}" "${subnet_ids}"

   echo 'Database subnet group created.'
fi

##
## Parameter group
##

check_db_parameter_group_exists "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}"
pg_exists="${__RESULT}"

if [[ 'false' == "${pg_exists}" ]]
then
   create_log_slow_queries_db_parameter_group "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}" "${DB_LOG_SLOW_QUERIES_PARAM_GRP_DESC}"
   
   echo 'Created log slow queries database parameter group.'
else
   echo 'WARN: the log slow queries parameter group is already created.'
fi

## 
## Database box
## 

get_database_state "${DB_NM}"
db_state="${__RESULT}"

if [[ -n "${db_state}" ]]
then
   echo "WARN: the database is already created (${db_state})"
else
   echo 'Creating database box ...'

   create_database "${DB_NM}" "${sgp_id}" "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}"  
   
   echo 'Database created.'
fi

get_database_endpoint "${DB_NM}"
db_endpoint="${__RESULT}"

echo
echo "Database box up and running at: ${db_endpoint}."

