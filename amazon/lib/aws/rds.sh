#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: rds.sh
#   DESCRIPTION: The script contains functions that use AWS AMI client to make 
#                calls to Amazon Relational Database Service (Amazon RDS).
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Returns the the DB Subnet Group status by name.
#
# Globals:
#  None
# Arguments:
# +dbsubnetg_nm     -- DB Subnet Group name.
# Returns:      
#  The DB Subnet Group status, or blanc if the DB Subnet Group is not found.  
#===============================================================================
function get_db_subnet_group_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local dbsubnetg_nm="${1}"
   local dbsubnetg_sts
  
   dbsubnetg_sts="$(aws rds describe-db-subnet-groups \
                          --filters Name=tag-key,Values='Name' \
                          --filters Name=tag-value,Values="${dbsubnetg_nm}" \
			 --query 'DBSubnetGroups[*].SubnetGroupStatus' \
                          --output text)"
  
  echo "${dbsubnetg_sts}"
 
  return 0
}

#===============================================================================
# Creates a DB Subnet Group.
#
# Globals:
#  None
# Arguments:
# +dbsubnetg_nm     -- DB Subnet Group name.
# +dbsubnetg_desc   -- DB Subnet Group description.
# +subnet_ids       -- List of subnet identifiers in the group.
#                      The list must be in JSON format, ex: 
#                         ["subnet-0d2ef22b8fea993c2","subnet-0e5eb1bfb7da6c56c"]
# Returns:      
#  None
#===============================================================================
function create_db_subnet_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local dbsubnetg_nm="${1}"
   local dbsubnetg_desc="${2}"
   local subnet_ids="${3}"

   aws rds create-db-subnet-group \
                           --db-subnet-group-name "${dbsubnetg_nm}" \
                           --db-subnet-group-description "${dbsubnetg_desc}" \
                           --tags "Key='Name',Value=${dbsubnetg_nm}" \
                           --subnet-ids "${subnet_ids}" >> "${LOG_DIR}/database.log"
 
  return 0
}

#===============================================================================
# Deletes a DB Subnet Group.
#
# Globals:
#  None
# Arguments:
# +dbsubnetg_nm     -- DB Subnet Group name.
# Returns:      
#  None
#===============================================================================
function delete_db_subnet_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local dbsubnetg_nm="${1}"

   aws rds delete-db-subnet-group --db-subnet-group-name "${dbsubnetg_nm}"
 
  return 0
}

#===============================================================================
# Returns the the DB Parameter Group description by name.
#
# The 'describe-db-parameter-groups' call throws an error if the parameter is 
# not found. A solution is to use 'awk' to filter from a list of results.
# 
# db_par_grp_nm="$(aws rds describe-db-parameter-groups \
#   --output text | awk -v param="${DB_MMDATA_PARAM_GRP_NM}" '{if ($4 == param) {print $4}}')"
#                       
# In this case, to bypass the issue, since AWS CLI provides built-in JSON-based 
# output filtering capabilities with the --query option,
# a JMESPATH expression can be used as a filter. 
#
# Globals:
#  None
# Arguments:
# +db_par_grp_nm     -- DB Parameter Group name.
# Returns:      
#  The DB Parameter Group description, or blanc if the DB Parameter Group is 
## not found.  
#===============================================================================
function get_db_parameter_group_desc()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local db_par_grp_nm="${1}"
   local db_par_grp_desc
  
   db_par_grp_desc="$(aws rds describe-db-parameter-groups \
                       --query "DBParameterGroups[?DBParameterGroupName=='${db_par_grp_nm}'].[Description]" --output text)" 
  
   echo "${db_par_grp_desc}"
 
   return 0
}

#===============================================================================
# Creates a DB Parameter Group.
#
# Globals:
#  None
# Arguments:
# +param_nm       -- DB Parameter Group name.
# +param_desc     -- DB Parameter Group description.
# +db_family      -- DB family.
# Returns:      
#  None  
#===============================================================================
function create_log_slow_queries_db_parameter_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local param_nm="${1}"
   local param_desc="${2}"
   local db_family="${3}"
  
   aws rds create-db-parameter-group \
                        --db-parameter-group-name "${param_nm}" \
                        --description "${param_desc}"  \
                        --db-parameter-group-family "${db_family}" >> "${LOG_DIR}/database.log"

   aws rds modify-db-parameter-group \
                       --db-parameter-group-name "${param_nm}" \
                       --parameters 'ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate' >> "${LOG_DIR}/database.log"
  
   aws rds modify-db-parameter-group \
                       --db-parameter-group-name "${param_nm}" \
                       --parameters 'ParameterName=long_query_time,ParameterValue=1,ApplyMethod=immediate' >> "${LOG_DIR}/database.log"

   return 0
}

#===============================================================================
# Deletes a DB Parameter Group.
#
# Globals:
#  None
# Arguments:
# +param_nm       -- DB Parameter Group name.
# Returns:      
#  None  
#===============================================================================
function delete_db_parameter_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local param_nm="${1}"

   aws rds delete-db-parameter-group --db-parameter-group-name "${param_nm}"

   return 0
}

#===============================================================================
# Returns the Database status by Database name.
#
# Globals:
#  None
# Arguments:
# +db_nm     -- DB name.
# Returns:      
#  The DB status, or blanc if the DB is not found.  
#===============================================================================
function get_database_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local db_nm="${1}"

   # AWS CLI provides built-in JSON-based output filtering capabilities with the --query option,
   # a JMESPATH expression is used as a filter. 
   local db_status

   db_status="$(aws rds describe-db-instances \
                       --query "DBInstances[?DBName=='${db_nm}'].[DBInstanceStatus]" --output text)"
  
   echo "${db_status}"
 
   return 0
}

#===============================================================================
# Returns the Database endpoint by Database name.
#
# Globals:
#  None
# Arguments:
# +db_nm     -- DB name.
# Returns:      
#  The DB endpoint, or blanc if the DB is not found.  
#===============================================================================
function get_database_endpoint()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local db_nm="${1}"

   # AWS CLI provides built-in JSON-based output filtering capabilities with the --query option,
   # a JMESPATH expression is used as a filter. 
   local db_endp
  
   db_endp="$(aws rds describe-db-instances \
                       --query "DBInstances[?DBName=='${db_nm}'].[Endpoint.Address]" --output text)"
  
   echo "${db_endp}"
 
   return 0
}

#===============================================================================
# Creates a Database Instance.
#
# Globals:
#  None
# Arguments:
# +db_nm     -- DB name.
# +sg_id     -- Security Group identifier.
# Returns:      
#  None  
#===============================================================================
function create_database()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local db_nm="${1}"
   local sg_id="${2}"

   if [[ ${DB_MMDATA_USE_MULTI_AZ} -gt 0 ]]; then

      # multi-az : can't use --availability-zone with --multi-az
      aws rds create-db-instance \
                      --db-instance-identifier "${DB_MMDATA_INSTANCE_NM}" \
                      --db-instance-class "${DB_MMDATA_INSTANCE_TYPE}" \
                      --allocated-storage "${DB_MMDATA_VOLUME_SIZE}" \
                      --db-name "${db_nm}" \
                      --engine "${DB_MMDATA_ENGINE}" \
                      --engine-version "${MYSQL_VERSION}" \
                      --port "${DB_MMDATA_PORT}" \
                      --no-auto-minor-version-upgrade \
                      --master-username "${DB_MMDATA_MAIN_USER_NM}" \
                      --master-user-password "${DB_MMDATA_MAIN_USER_PWD}" \
                      --backup-retention-period "${DB_MMDATA_BACKUP_RET_PERIOD}" \
                      --no-publicly-accessible \
                      --region "${DEPLOY_REGION}" \
                      --multi-az \
                      --vpc-security-group-ids "${sg_id}" \
                      --db-subnet-group-name "${DB_MMDATA_SUB_GRP_NM}" \
                      --db-parameter-group-name "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}" >> "${LOG_DIR}/database.log"
   else
      ## No multi availability zone
      aws rds create-db-instance \
                      --db-instance-identifier "${DB_MMDATA_INSTANCE_NM}" \
                      --db-instance-class "${DB_MMDATA_INSTANCE_TYPE}" \
                      --allocated-storage "${DB_MMDATA_VOLUME_SIZE}" \
                      --db-name "${db_nm}" \
                      --engine "${DB_MMDATA_ENGINE}" \
                      --engine-version "${MYSQL_VERSION}" \
                      --port "${DB_MMDATA_PORT}" \
                      --no-auto-minor-version-upgrade \
                      --master-username "${DB_MMDATA_MAIN_USER_NM}" \
                      --master-user-password "${DB_MMDATA_MAIN_USER_PWD}" \
                      --backup-retention-period "${DB_MMDATA_BACKUP_RET_PERIOD}" \
                      --no-publicly-accessible \
                      --region "${DEPLOY_REGION}" \
                      --availability-zone "${DEPLOY_ZONE_1}"  \
                      --vpc-security-group-ids "${sg_id}" \
                      --db-subnet-group-name "${DB_MMDATA_SUB_GRP_NM}" \
                      --db-parameter-group-name "${DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM}" >> "${LOG_DIR}/database.log"
   fi

   aws rds wait db-instance-available --db-instance-identifier "${DB_MMDATA_INSTANCE_NM}"
 
   return 0
}

#===============================================================================
# Deletes a Database Instance whithout creating a backup copy.
#
# Globals:
#  None
# Arguments:
# +db_nm     -- DB name.
# Returns:      
#  None  
#===============================================================================
function delete_database()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local db_nm="${1}"

   # terminate rds (with no final snapshot)
   aws rds delete-db-instance \
                       --db-instance-identifier "${db_nm}" \
                       --skip-final-snapshot >> "${LOG_DIR}/database.log" 

   aws rds wait db-instance-deleted --db-instance-identifier "${db_nm}"
 
   return 0
}

#===============================================================================
# Returns the list of Database Snapshot identifiers by Database name.
# The returned list is a string where the identifiers are separated by space. 
#
# Globals:
#  None
# Arguments:
# +db_nm     -- DB name.
# Returns:      
#  The list of Database Snapshot identifiers, or blanc if no Snapshot is found.  
#===============================================================================
function get_database_snapshot_ids()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local db_nm="${1}"

   # AWS CLI provides built-in JSON-based output filtering capabilities with the --query option,
   # a JMESPATH expression is used as a filter. 
   local db_snapshot_ids

   db_snapshot_ids="$(aws rds describe-db-snapshots \
                       --query "DBSnapshots[?DBInstanceIdentifier=='${db_nm}'].DBSnapshotIdentifier" \
                       --output text)"
  
   echo "${db_snapshot_ids}"
 
   return 0
}

#===============================================================================
# Deletes a Database Snapshot.
#
# Globals:
#  None
# Arguments:
# +db_snapshot_id   -- The Database Snapshot identifier.
# Returns:      
#  None  
#===============================================================================
function delete_database_snapshot()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local db_snapshot_id="${1}"

   aws rds delete-db-snapshot \
              --db-snapshot-identifier "${db_snapshot_id}" >> "${LOG_DIR}/database.log"

   return 0
}
