#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## database schema, tables, data are created with the deploy database script.

echo '************'
echo 'Database box'
echo '************'
echo

dtc_id="$(get_datacenter_id "${DTC_NM}")"

if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

subnet_ids="$(get_subnet_ids "${dtc_id}")"

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

sgp_id="$(get_security_group_id "${DB_INST_SEC_GRP_NM}")"
  
if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the database security group is already created.'
else
   sgp_id="$(create_security_group "${dtc_id}" "${DB_INST_SEC_GRP_NM}" 'Database security group.')"

   echo 'Database security group created.'
fi

## 
## Subnet group
## 

db_subnet_group_status="$(get_db_subnet_group_status "${DB_INST_SUBNET_GRP_NM}")"

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

pg_exists="$(check_log_slow_queries_db_parameter_group_exists "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}")"

if [[ -z "${pg_exists}" ]]
then
   create_log_slow_queries_db_parameter_group "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}" "${DB_LOG_SLOW_QUERIES_PARAM_GRP_DESC}"
   
   echo 'Created log slow queries database parameter group.'
else
   echo 'WARN: the log slow queries parameter group is already created.'
fi

## 
## Database box
## 

db_state="$(get_database_state "${DB_NM}")"

if [[ -n "${db_state}" ]]
then
   echo "WARN: the database is already created (${db_state})"
else
   echo 'Creating database box ...'

   create_database "${DB_NM}" "${sgp_id}" "${DB_LOG_SLOW_QUERIES_PARAM_GRP_NM}"  
   
   echo 'Database created.'
fi

db_endpoint="$(get_database_endpoint "${DB_NM}")"

echo
echo "Database box up and running at: ${db_endpoint}."
echo
