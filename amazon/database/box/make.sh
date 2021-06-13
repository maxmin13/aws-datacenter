#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## Database schema, tables, data are created with the deploy Database script.

echo '************'
echo 'Database box'
echo '************'
echo

dtc_id="$(get_datacenter_id "${DTC_NM}")"

if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: Data Center not found.'
   exit 1
else
   echo "* Data Center ID: ${dtc_id}."
fi

subnet_ids="$(get_subnet_ids "${dtc_id}")"

if [[ -z "${subnet_ids}" ]]
then
   echo '* ERROR: subnets not found.'
   exit 1
else
   echo "* Subnet IDs: ${subnet_ids}."
fi

echo

## 
## Security Group
##

sgp_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"
  
if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Database Security Group is already created.'
else
   sgp_id="$(create_security_group "${dtc_id}" "${DB_MMDATA_SEC_GRP_NM}" "Database Security Group")"

   echo 'Database Security Group created.'
fi

## 
## Database Subnet group
## 

db_subnet_group_status="$(get_db_subnet_group_status "${DB_MMDATA_SUB_GRP_NM}")"

if [[ -n "${db_subnet_group_status}" ]]
then
   echo 'WARN: the Database Subnet group is already created.'
else 
   create_db_subnet_group "${DB_MMDATA_SUB_GRP_NM}" "${DB_MMDATA_SUB_GRP_DESC}" "${subnet_ids}"

   echo 'Database Subnet group created.'
fi

##
## Parameter Group
##

pg_exists="$(check_log_slow_queries_db_parameter_group_exists "${DB_MMDATA_LOG_SLOW_QUERIES_PARAM_GRP_NM}")"

if [[ -z "${pg_exists}" ]]
then
   create_log_slow_queries_db_parameter_group "${DB_MMDATA_LOG_SLOW_QUERIES_PARAM_GRP_NM}" "${DB_MMDATA_LOG_SLOW_QUERIES_PARAM_GRP_DESC}"
   
   echo 'Created log slow queries database parameter group.'
else
   echo 'WARN: the log slow queries parameter group is already created.'
fi

## 
## Database box
## 

db_state="$(get_database_state "${DB_MMDATA_NM}")"

if [[ -n "${db_state}" ]]
then
   echo "WARN: the Database is already created (${db_state})"
else
   echo 'Creating Database box ...'

   create_database "${DB_MMDATA_NM}" "${sgp_id}" "${DB_MMDATA_LOG_SLOW_QUERIES_PARAM_GRP_NM}"  
   
   echo 'Database created.'
fi

db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

echo
echo "Database box up and running at: ${db_endpoint}."
echo
