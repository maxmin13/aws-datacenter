#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## Database schema, tables, data are created with the deploy database script.

echo '********'
echo 'Database'
echo '********'
echo

# Checking if the Database already exists
db_status="$(get_database_status "${DB_MMDATA_NM}")"

if [[ -n "${db_status}" ]]
then
   echo "ERROR: The '${DB_MMDATA_NM}' Database is already created"
   exit 1
fi

vpc_id="$(get_vpc_id "${VPC_NM}")"

if [[ -z "${vpc_id}" ]]
then
   echo 'Error, VPC not found.'
   exit 1
else
   echo "* VPC ID: '${vpc_id}'"
fi

subnet_ids="$(get_subnet_ids "${vpc_id}")"

if [[ -z "${subnet_ids}" ]]
then
   echo 'Error, Subnets not found.'
   exit 1
else
   echo "* Subnet IDs: '${subnet_ids}'"
fi

echo

## ***********************
## Database Security Group
## ***********************

sg_id="$(get_security_group_id "${DB_MMDATA_SEC_GRP_NM}")"
  
if [[ -n "${sg_id}" ]]
then
   echo "ERROR: The '${DB_MMDATA_SEC_GRP_NM}' Database Security Group is already created"
   exit 1
fi

sg_id="$(create_security_group "${vpc_id}" "${DB_MMDATA_SEC_GRP_NM}" "Database security group")"
echo "'${DB_MMDATA_SEC_GRP_NM}' Database Security Group created"

## *********************
## Database Subnet Group
## *********************

dbsubnetg_sts="$(get_db_subnet_group_status "${DB_MMDATA_SUB_GRP_NM}")"

if [[ -n "${dbsubnetg_sts}" ]]
then
   echo "ERROR: '${DB_MMDATA_SUB_GRP_NM}' DB Subnet Group already created"
   exit 1
fi

create_db_subnet_group "${DB_MMDATA_SUB_GRP_NM}" "${DB_MMDATA_SUB_GRP_DESC}" "${subnet_ids}"
echo "'${DB_MMDATA_SUB_GRP_NM}' DB Subnet Group created"

## ************************
## Database Parameter Group
## ************************

## Log slow queries and set the trigger time to be 1 second.
## Any query taking more than 1 second will be logged.

param_desc="$(get_db_parameter_group_desc "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}")"                     

if [[ -n "${param_desc}" ]]
then
   echo "ERROR: '${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}' DB Parameter Group already created"
   exit 1
fi

create_log_slow_queries_db_parameter_group \
                       "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}" \
                       "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_DESC}"  \
                       "${DB_MMDATA_FAMILY}" 
                      
echo "'${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}' DB Parameter Group created"

## *****************
## Database instance
## *****************

echo "Creating '${DB_MMDATA_NM}' Database instance ..."

create_database "${DB_MMDATA_NM}" "${sg_id}"  

# this is the address, or endpoint, for the db
db_endpoint="$(get_database_endpoint "${DB_MMDATA_NM}")"

echo "Database endpoint '${db_endpoint}'"

echo 'Database setup completed'
echo
