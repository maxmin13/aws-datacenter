#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
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

#MYSQL_VERSION='8.0'
MYSQL_VERSION='5.7'
#DB_FAMILY='mysql8.0'
DB_FAMILY='mysql5.7'
DB_ENGINE='MYSQL'
# the instance type to use (different from EC2 instance types)
# Represents compute and memory capacity class 
DB_INSTANCE_TYPE='db.t3.micro'
DB_VOLUME_SIZE='10' # in GB
# 1=use multi-az, 0=don't
# Disable automated Database backups
DB_BACKUP_RET_PERIOD='0'

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
      echo 'ERROR: missing mandatory arguments.'
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
# +subnet_ids       -- List of Subnet identifiers in the group.
#                      The list must be in JSON format, ex: 
#                      ["subnet-0d2ef22b8fea993c2","subnet-0e5eb1bfb7da6c56c"]
# Returns:      
#  None
#===============================================================================
function create_db_subnet_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local dbsubnetg_nm="${1}"
   local dbsubnetg_desc="${2}"
   local subnet_ids="${3}"

   aws rds create-db-subnet-group \
       --db-subnet-group-name "${dbsubnetg_nm}" \
       --db-subnet-group-description "${dbsubnetg_desc}" \
       --tags "Key='Name',Value=${dbsubnetg_nm}" \
       --subnet-ids "${subnet_ids}" >> /dev/null
 
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
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local dbsubnetg_nm="${1}"

   aws rds delete-db-subnet-group --db-subnet-group-name "${dbsubnetg_nm}"
 
  return 0
}

#===============================================================================
# You manage your DB engine configuration by associating your DB instances with 
# parameter groups. Amazon RDS defines parameter groups with default settings 
# that apply to newly created DB instances.
# If you want to use your own parameter group, you create a new parameter group 
# and modify the parameters that you want to.
# If you update parameters within a DB parameter group, the changes apply to all 
# DB instances that are associated with that parameter group.
#
# Globals:
#  None
# Arguments:
# +db_pgp_nm   -- the name of the database parameter group.
# +db_pgp_desc -- the description of the database parameter group.
# Returns:      
#  None  
#===============================================================================
function create_log_slow_queries_db_parameter_group()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local db_pgp_nm="${1}"
   local db_pgp_desc="${2}"
   
   {
      aws rds create-db-parameter-group \
          --db-parameter-group-name "${db_pgp_nm}" \
          --description "${db_pgp_desc}"  \
          --db-parameter-group-family "${DB_FAMILY}"

      aws rds modify-db-parameter-group \
          --db-parameter-group-name "${db_pgp_nm}" \
          --parameters 'ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate' 
  
      aws rds modify-db-parameter-group \
          --db-parameter-group-name "${db_pgp_nm}" \
          --parameters 'ParameterName=long_query_time,ParameterValue=1,ApplyMethod=immediate'
   } >>/dev/null

   return 0
}

#===============================================================================
# Deletes the slow query DB Parameter Group.
#
# Globals:
#  None
# Arguments:
# +db_pgp_nm   -- the name of the database parameter group.
# Returns:      
#  None  
#===============================================================================
function delete_log_slow_queries_db_parameter_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local db_pgp_nm="${1}"
   
   aws rds delete-db-parameter-group \
       --db-parameter-group-name "${db_pgp_nm}"

   return 0
}

#===============================================================================
# Checks if the slow query DB Parameter Group exists. 
#
# Globals:
#  None
# Arguments:
# +db_pgp_nm   -- the name of the database parameter group.
# Returns:      
#  The description of the parameter, or blanc if it doesn't exist.
#===============================================================================
function check_log_slow_queries_db_parameter_group_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local db_pgp_nm="${1}"
   local description
  
   description="$(aws rds describe-db-parameter-groups \
       --query "DBParameterGroups[?DBParameterGroupName=='${db_pgp_nm}'].Description" \
       --output text)" 
  
   echo "${description}"

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
function get_database_state()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local db_nm="${1}"

   # AWS CLI provides built-in JSON-based output filtering capabilities with the --query option,
   # a JMESPATH expression is used as a filter. 
   local db_status

   db_status="$(aws rds describe-db-instances \
       --query "DBInstances[?DBName=='${db_nm}'].[DBInstanceStatus]" \
       --output text)"
  
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
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local db_nm="${1}"

   # AWS CLI provides built-in JSON-based output filtering capabilities with the --query option,
   # a JMESPATH expression is used as a filter. 
   local db_endp
  
   db_endp="$(aws rds describe-db-instances \
       --query "DBInstances[?DBName=='${db_nm}'].[Endpoint.Address]" \
       --output text)"
  
   echo "${db_endp}"
 
   return 0
}

#===============================================================================
# Creates a Database Instance.
#
# Globals:
#  None
# Arguments:
# +db_nm             -- DB name.
# +sg_id             -- Security Group identifier.
# +db_pgp_nm         -- the name of a DB parameter group.
# Returns:      
#  None  
#===============================================================================
function create_database()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local db_nm="${1}"
   local sg_id="${2}"
   local db_pgp_nm="${3}"

   exists="$(check_log_slow_queries_db_parameter_group_exists "${db_pgp_nm}")"
   
   if [[ -z "${exists}" ]]
   then
      echo 'ERROR: slow query parameter group not found.'
      
      exit 1
   fi

   ## No multi availability zone
   aws rds create-db-instance \
       --db-instance-identifier "${DB_MMDATA_INSTANCE_NM}" \
       --db-instance-class "${DB_INSTANCE_TYPE}" \
       --allocated-storage "${DB_VOLUME_SIZE}" \
       --db-name "${db_nm}" \
       --engine "${DB_ENGINE}" \
       --engine-version "${MYSQL_VERSION}" \
       --port "${DB_MMDATA_PORT}" \
       --no-auto-minor-version-upgrade \
       --master-username "${DB_MMDATA_MAIN_USER_NM}" \
       --master-user-password "${DB_MMDATA_MAIN_USER_PWD}" \
       --backup-retention-period "${DB_BACKUP_RET_PERIOD}" \
       --no-publicly-accessible \
       --region "${DTC_DEPLOY_REGION}" \
       --availability-zone "${DTC_DEPLOY_ZONE_1}"  \
       --vpc-security-group-ids "${sg_id}" \
       --db-subnet-group-name "${DB_MMDATA_SUB_GRP_NM}" \
       --db-parameter-group-name "${db_pgp_nm}" >> /dev/null

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
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local db_nm="${1}"

   # terminate rds (with no final snapshot)
   aws rds delete-db-instance \
       --db-instance-identifier "${db_nm}" \
       --skip-final-snapshot >> /dev/null 

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
      echo 'ERROR: missing mandatory arguments.'
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
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local db_snapshot_id="${1}"

   aws rds delete-db-snapshot \
       --db-snapshot-identifier "${db_snapshot_id}" >> /dev/null

   return 0
}
