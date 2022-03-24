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
#                calls to Amazon Relational database Service (Amazon RDS).
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
# Disable automated database backups
DB_BACKUP_RET_PERIOD='0'

#===============================================================================
# Returns the the database subnet Group status by name.
#
# Globals:
#  None
# Arguments:
# +dbsubnetg_nm -- database subnet Group name.
# Returns:      
#  The database subnet Group status in the global __RESULT variable.  
#===============================================================================
function get_db_subnet_group_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   __RESULT=''
   local exit_code=0
   local -r dbsubnetg_nm="${1}"
   local dbsubnetg_sts=''
  
   dbsubnetg_sts="$(aws rds describe-db-subnet-groups \
      --filters Name=tag-key,Values='Name' \
      --filters Name=tag-value,Values="${dbsubnetg_nm}" \
      --query 'DBSubnetGroups[*].SubnetGroupStatus' \
      --output text)"
      
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving subnet group status.'
      return "${exit_code}"
   fi     
  
   __RESULT="${dbsubnetg_sts}"
 
   return "${exit_code}"
}

#===============================================================================
# Creates a database subnet Group.
#
# Globals:
#  None
# Arguments:
# +dbsubnetg_nm   -- database subnet Group name.
# +dbsubnetg_desc -- database subnet Group description.
# +subnet_ids     -- list of subnet identifiers in the group.
#                    The list must be in JSON format, ex: 
#                    ["subnet-0d2ef22b8fea993c2","subnet-0e5eb1bfb7da6c56c"]
# Returns:      
#  None
#===============================================================================
function create_db_subnet_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   local -r dbsubnetg_nm="${1}"
   local -r dbsubnetg_desc="${2}"
   local -r subnet_ids="${3}"

   aws rds create-db-subnet-group \
       --db-subnet-group-name "${dbsubnetg_nm}" \
       --db-subnet-group-description "${dbsubnetg_desc}" \
       --tags "Key='Name',Value=${dbsubnetg_nm}" \
       --subnet-ids "${subnet_ids}" >> /dev/null
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating dababase subnet group.'
   fi     
       
   return "${exit_code}"
}

#===============================================================================
# Deletes a database subnet group.
#
# Globals:
#  None
# Arguments:
# +dbsubnetg_nm -- database subnet group name.
# Returns:      
#  None
#===============================================================================
function delete_db_subnet_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   local -r dbsubnetg_nm="${1}"

   aws rds delete-db-subnet-group --db-subnet-group-name "${dbsubnetg_nm}"
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting dababase subnet group.'
   fi     
       
   return "${exit_code}"
}

#===============================================================================
# You manage your database engine configuration by associating your database instances with 
# parameter groups. Amazon RDS defines parameter groups with default settings 
# that apply to newly created database instances.
# If you want to use your own parameter group, you create a new parameter group 
# and modify the parameters that you want to.
# If you update parameters within a database parameter group, the changes apply to all 
# database instances that are associated with that parameter group.
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
      return 1
   fi
   
   local exit_code=0
   local -r db_pgp_nm="${1}"
   local -r db_pgp_desc="${2}"
   
   {
      aws rds create-db-parameter-group \
          --db-parameter-group-name "${db_pgp_nm}" \
          --description "${db_pgp_desc}"  \
          --db-parameter-group-family "${DB_FAMILY}"
          
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: creating parameter group.'
         return "${exit_code}"
      fi      

      aws rds modify-db-parameter-group \
          --db-parameter-group-name "${db_pgp_nm}" \
          --parameters 'ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate' 
          
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: modifying parameter group.'
         return "${exit_code}"
      fi    
  
      aws rds modify-db-parameter-group \
          --db-parameter-group-name "${db_pgp_nm}" \
          --parameters 'ParameterName=long_query_time,ParameterValue=1,ApplyMethod=immediate'
          
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: modifying parameter group.'
         return "${exit_code}"
      fi    
          
   } >>/dev/null

   return "${exit_code}"
}

#===============================================================================
# Deletes the slow query database parameter group.
#
# Globals:
#  None
# Arguments:
# +db_pgp_nm -- the name of the database parameter group.
# Returns:      
#  None  
#===============================================================================
function delete_log_slow_queries_db_parameter_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local exit_code=0
   local -r db_pgp_nm="${1}"
   
   aws rds delete-db-parameter-group \
       --db-parameter-group-name "${db_pgp_nm}"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting parameter group.'
   fi        

   return "${exit_code}"
}

#===============================================================================
# Checks if the slow query database parameter group exists. 
#
# Globals:
#  None
# Arguments:
# +db_pgp_nm -- the name of the database parameter group.
# Returns:      
#  true/false in the global __RESULT variable.
#===============================================================================
function check_db_parameter_group_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   __RESULT=''
   local exit_code=0
   local -r db_pgp_nm="${1}"
   local description=''
   local exists='false'
  
   description="$(aws rds describe-db-parameter-groups \
       --query "DBParameterGroups[?DBParameterGroupName=='${db_pgp_nm}'].Description" \
       --output text)" 
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving database parameter group description.'
      return "${exit_code}"
   fi
   
   if [[ -n "${description}" ]]  
   then
      exists='true'
   fi                     
            
   __RESULT="${exists}"
 
   return "${exit_code}"
}

#===============================================================================
# Returns the database status by database name.
#
# Globals:
#  None
# Arguments:
# +database_nm -- database name.
# Returns:      
#  The database status in the global __RESULT variable. 
#===============================================================================
function get_database_state()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   __RESULT=''
   local exit_code=0
   local -r database_nm="${1}"
   local db_status=''

   db_status="$(aws rds describe-db-instances \
       --query "DBInstances[?DBName=='${database_nm}'].[DBInstanceStatus]" \
       --output text)"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving database state.'
      return "${exit_code}"
   fi    
  
   __RESULT="${db_status}"
 
   return "${exit_code}"
}

#===============================================================================
# Returns the database endpoint by database name.
#
# Globals:
#  None
# Arguments:
# +database_nm -- database name.
# Returns:      
#  The database endpoint address in the global __RESULT variable.  
#===============================================================================
function get_database_endpoint()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   __RESULT=''
   local exit_code=0
   local -r database_nm="${1}"
   local db_endpoint=''
  
   db_endpoint="$(aws rds describe-db-instances \
       --query "DBInstances[?DBName=='${database_nm}'].[Endpoint.Address]" \
       --output text)"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving database endpoint.'
   fi    
  
   __RESULT="${db_endpoint}"
 
   return "${exit_code}"
}

#===============================================================================
# Creates a database Instance.
#
# Globals:
#  None
# Arguments:
# +database_nm -- database name.
# +sg_id       -- security group identifier.
# +db_pgp_nm   -- the name of a database parameter group.
# Returns:      
#  None  
#===============================================================================
function create_database()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   __RESULT=''
   local exit_code=0
   local -r database_nm="${1}"
   local -r sgp_id="${2}"
   local -r db_pgp_nm="${3}"
   local exists='false'

   check_db_parameter_group_exists "${db_pgp_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: checking database parameter group exists.'
      return "${exit_code}"
   fi    
   
   exists="${__RESULT}"
   
   if [[ 'false' == "${exists}" ]]
   then
      echo 'ERROR: slow query parameter group not found.'     
      return 1
   fi

   ## No multi availability zone
   aws rds create-db-instance \
       --db-instance-identifier "${DB_INST_NM}" \
       --db-instance-class "${DB_INSTANCE_TYPE}" \
       --allocated-storage "${DB_VOLUME_SIZE}" \
       --db-name "${database_nm}" \
       --engine "${DB_ENGINE}" \
       --engine-version "${MYSQL_VERSION}" \
       --port "${DB_INST_PORT}" \
       --no-auto-minor-version-upgrade \
       --master-username "${DB_MAIN_USER_NM}" \
       --master-user-password "${DB_MAIN_USER_PWD}" \
       --backup-retention-period "${DB_BACKUP_RET_PERIOD}" \
       --no-publicly-accessible \
       --region "${DTC_REGION}" \
       --availability-zone "${DTC_AZ_1}"  \
       --vpc-security-group-ids "${sgp_id}" \
       --db-subnet-group-name "${DB_INST_SUBNET_GRP_NM}" \
       --db-parameter-group-name "${db_pgp_nm}" >> /dev/null
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating database.'
      return "${exit_code}"
   fi    

   aws rds wait db-instance-available --db-instance-identifier "${DB_INST_NM}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: waiting for database.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Deletes a database instance without creating a backup copy.
#
# Globals:
#  None
# Arguments:
# +database_nm -- database name.
# Returns:      
#  None  
#===============================================================================
function delete_database()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   local -r database_nm="${1}"

   # terminate rds (with no final snapshot)
   aws rds delete-db-instance \
       --db-instance-identifier "${database_nm}" \
       --skip-final-snapshot >> /dev/null 
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting database.'
      return "${exit_code}"
   fi      

   aws rds wait db-instance-deleted --db-instance-identifier "${database_nm}"
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: waiting for database.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Returns the list of database Snapshot identifiers by database name.
# The returned list is a string where the identifiers are separated by space. 
#
# Globals:
#  None
# Arguments:
# +database_nm -- database name.
# Returns:      
#  The list of database Snapshot identifiers in the global __RESULT variable.  
#===============================================================================
function get_database_snapshot_ids()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   __RESULT=''
   local exit_code=0
   local -r database_nm="${1}"
   local db_snapshot_ids=''

   db_snapshot_ids="$(aws rds describe-db-snapshots \
       --query "DBSnapshots[?DBInstanceIdentifier=='${database_nm}'].DBSnapshotIdentifier" \
       --output text)"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving database snapshot ids.'
      return "${exit_code}"
   fi  
 
   __RESULT="${db_snapshot_ids}"
 
   return "${exit_code}"
}

#===============================================================================
# Deletes a database Snapshot.
#
# Globals:
#  None
# Arguments:
# +db_snapshot_id -- database snapshot identifier.
# Returns:      
#  None  
#===============================================================================
function delete_database_snapshot()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   local -r db_snapshot_id="${1}"

   aws rds delete-db-snapshot \
       --db-snapshot-identifier "${db_snapshot_id}" >> /dev/null

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting database snapshot.'
   fi
   
   return "${exit_code}"
}
