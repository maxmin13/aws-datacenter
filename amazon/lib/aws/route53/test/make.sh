#!/usr/bin/bash

set +o errexit
set +o pipefail
set +o nounset
set +o xtrace

# Find the maxmin.it. hosted zone ID.
_HOSTED_ZONE_ID="$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='${MAXMIN_TLD}'].{Id: Id}" \
    --output text)" 
    
HOSTED_ZONE_ID="$(echo "${_HOSTED_ZONE_ID}" | cut -d'/' -f 3)" 
 
# This is the ID of the hosted zone created with the load balancer, it is not deleted when the load
# balancer is deleted, so I use it for the tests.
ALIAS_TARGET_HOSTED_ZONE_ID='Z32O12XQLNTSW2'
RECORD_COMMENT="Test record"   
counter=0

##
## Functions used to handle test data.
##

#################################################
# Creates aws-alias records.
# Throws an error if the record is already created.
################################################# 
function __helper_create_alias_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local -r domain_nm="${1}"
   local -r target_domain_nm="${2}"
   local -r target_hosted_zone_id="${3}"
   local request_id=''

   if [[ -z "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[? Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then   
       __helper_create_delete_alias_record \
           'CREATE' "${domain_nm}" "${target_domain_nm}" "${target_hosted_zone_id}"
       request_id="${__RESULT}"
   fi
   
   __RESULT="${request_id}"
   
   return 0
}

#################################################
# Deletes aws-alias records.
################################################# 
function __helper_delete_alias_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local -r domain_nm="${1}"
   local -r target_domain_nm="${2}"
   local -r target_hosted_zone_id="${3}"
   local request_id=''

   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[? Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then   
       __helper_create_delete_alias_record \
          'DELETE' "${domain_nm}" "${target_domain_nm}" "${target_hosted_zone_id}"      
       request_id="${__RESULT}" 
   fi
   
   __RESULT="${request_id}"   

   return 0
}

function __helper_create_delete_alias_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local -r action="${1}"
   local -r domain_nm="${2}"
   local -r target_domain_nm="${3}"
   local -r target_hosted_zone_id="${4}"
   local -r comment="${RECORD_COMMENT}"
   local template=''
   local request_id=''
   local request_body=''
   
   template=$(cat <<-'EOF' 
        {
           "Comment":"SEDcommentSED",
           "Changes":[
              {
                 "Action":"SEDactionSED",
                 "ResourceRecordSet":{
                    "Name":"SEDdomain_nmSED",
                    "Type":"A",
                    "AliasTarget":{
                       "HostedZoneId":"SEDtarget_hosted_zone_idSED",
                       "DNSName":"SEDtarget_domain_nmSED",
                       "EvaluateTargetHealth":false
                    }
                 }
              }
           ]
        }       
	EOF
   )

   request_body="$(printf '%b\n' "${template}" \
       | sed -e "s/SEDdomain_nmSED/${domain_nm}/g" \
           -e "s/SEDtarget_domain_nmSED/${target_domain_nm}/g" \
           -e "s/SEDtarget_hosted_zone_idSED/${target_hosted_zone_id}/g" \
           -e "s/SEDcommentSED/${comment}/g" \
           -e "s/SEDactionSED/${action}/g")" 
  
   request_id="$(aws route53 change-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --change-batch "${request_body}" \
       --query ChangeInfo.Id \
       --output text)"
   
   __RESULT="${request_id}"
   
   return 0
}

####################################################
# Creates A or NS records.
# Throws an error if the records is already created.
####################################################
function __helper_create_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local -r domain_nm="${1}"
   local -r record_value="${2}"
   local -r record_type="${3}"
   local request_id=''

   if [[ -z "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[? Type=='${record_type}' && Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then   
       __helper_create_delete_record \
           'CREATE' "${domain_nm}" "${record_value}" "${record_type}"  
       request_id="${__RESULT}" 
   fi
   
   __RESULT="${request_id}"
    
   return 0
}

#################################################
# Deletes A or NS records.
################################################# 
function __helper_delete_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local -r domain_nm="${1}"
   local -r record_value="${2}"
   local -r record_type="${3}"
   local request_id=''

   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[? Type=='${record_type}' && Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then   
       __helper_create_delete_record 'DELETE' "${domain_nm}" "${record_value}" "${record_type}" 
       request_id="${__RESULT}"
   fi
    
   __RESULT="${request_id}"    
   
   return 0
}

function __helper_create_delete_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local -r action="${1}"
   local -r domain_nm="${2}"
   local -r record_value="${3}"
   local -r record_type="${4}"
   local -r comment="${RECORD_COMMENT}"
   local template=''
   local request_id=''
   local request_body=''
   
   template=$(cat <<-'EOF'
        {
           "Comment":"SEDcommentSED",
           "Changes":[
              {
                 "Action":"SEDactionSED",
                 "ResourceRecordSet":{
                    "Name":"SEDdomain_nameSED",
                    "Type":"SEDrecord_typeSED",
                    "TTL":120,
                    "ResourceRecords":[
                       {
                          "Value":"SEDrecord_valueSED"
                       }
                    ]
                 }
              }
           ]
        }
	EOF
   )
   
   request_body="$(printf '%b\n' "${template}" \
       | sed -e "s/SEDdomain_nameSED/${domain_nm}/g" \
             -e "s/SEDrecord_valueSED/${record_value}/g" \
             -e "s/SEDrecord_typeSED/${record_type}/g" \
             -e "s/SEDcommentSED/${comment}/g" \
             -e "s/SEDactionSED/${action}/g")"
             
   request_id="$(aws route53 change-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --change-batch "${request_body}" \
       --query ChangeInfo.Id \
       --output text )"
   
   __RESULT="${request_id}"       
   
   return 0
} 

function __helper_clear_resources 
{
   # Clear the global __RESULT variable.
   __RESULT=''

   __helper_delete_record \
       'dns.maxmin.it.' '18.203.73.111' 'A' 

   __helper_delete_record \
       'dns.maxmin.it.' 'dns.maxmin.it.' 'NS'  

   __helper_delete_alias_record \
       'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
       "${ALIAS_TARGET_HOSTED_ZONE_ID}"
       
   echo 'Test resources cleared.'     
        
   return 0
}

if [[ -z "${_HOSTED_ZONE_ID}" ]]
then
  echo 'ERROR: hosted zone not found, skipping the tests ...'
  exit
fi

##
##
##
echo 'Starting route53.sh script tests ...'
echo
##
##
##

trap "__helper_clear_resources" EXIT

###########################################
## TEST: create_record
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing parameter.
#

set +e
create_record  'A' 'dns.maxmin.it.' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing create_record with missing parameter.'
   counter=$((counter +1))
fi 

#
# Create A record successfully.
#

set +e
create_record  'A' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing create_record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_record creating A record.'
   counter=$((counter +1))
fi

# Check the value.
record_value="$(aws route53 list-resource-record-sets \
    --hosted-zone-id "${HOSTED_ZONE_ID}" \
    --query "ResourceRecordSets[? Type == 'A' && Name == 'dns.maxmin.it.' ].ResourceRecords[].Value" \
    --output text)"
    
if [[ '18.203.73.111' != "${record_value}" ]]
then
   echo 'ERROR: testing create_record with A record and valid domain.'
   counter=$((counter +1))
fi  

#
# Create twice the same record.
#

set +e
create_record  'A' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

if [[ 0 -eq ""${exit_code}"" ]]
then
   echo 'ERROR: testing create_record creating A record twice.'
   counter=$((counter +1))
fi

#
# Create NS record successfully.
#

# Create the record.
set +e
create_record  'NS' 'dns.maxmin.it.' 'dns.maxmin.it.' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing create_record with NS record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_record request value status.'
   counter=$((counter +1))
fi

# Check the value.
record_value="$(aws route53 list-resource-record-sets \
    --hosted-zone-id "${HOSTED_ZONE_ID}" \
    --query "ResourceRecordSets[? Type == 'NS' && Name == 'dns.maxmin.it.' ].ResourceRecords[].Value" \
    --output text)"
    
if [[ 'dns.maxmin.it.' != "${record_value}" ]]
then
   echo 'ERROR: testing create_record with NS record and valid domain.'
   counter=$((counter +1))
fi

echo 'create_record tests completed.'

__helper_clear_resources > /dev/null 2>&1 

###########################################
## TEST: create_loadbalancer_record
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing parameter.
#

set +e
create_loadbalancer_record \
    'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing create_loadbalancer_record with missing parameter.'
   counter=$((counter +1))
fi 

#
# Create record successfully.
#

set +e
create_loadbalancer_record \
    'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" \
     > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing create_loadbalancer_record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_loadbalancer_record.'
   counter=$((counter +1))
fi

# Check the value {AWS alias are A type records}.
record_value="$(aws route53 list-resource-record-sets \
    --hosted-zone-id "${HOSTED_ZONE_ID}" \
    --query "ResourceRecordSets[? Type == 'A' && Name == 'lbal.maxmin.it.' ].AliasTarget.DNSName" \
    --output text)"
    
if [[ '1203266565.eu-west-1.elb.amazonaws.com.' != "${record_value}" ]]
then
   echo 'ERROR: testing get_record_value with aws-record record and valid domain.'
   counter=$((counter +1))
fi 


# Create twice the same record.
set +e
create_loadbalancer_record \
    'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" \
     > /dev/null 2>&1 
exit_code=$?
set -e

# Error expected.
if [[ 0 -eq ""${exit_code}"" ]]
then
   echo 'ERROR: testing create_loadbalancer_record creating record twice.'
   counter=$((counter +1))
fi

echo 'create_loadbalancer_record tests completed.'

__helper_clear_resources > /dev/null 2>&1 
    
###########################################
## TEST: get_record_value
###########################################

__helper_clear_resources > /dev/null 2>&1 

# Insert a dns.maxmin.it.maxmin.it NS and A records in the hosted zone.
__helper_create_record \
    'dns.maxmin.it.' '18.203.73.111' 'A' > /dev/null 

__helper_create_record \
    'dns.maxmin.it.' 'dns.maxmin.it.' 'NS' > /dev/null 

__helper_create_alias_record \
    'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Missing argument.
#

set +e
get_record_value 'dns.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

if test 0 -eq ""${exit_code}""
then
   echo 'ERROR: testing get_record_value with missing argument.'
   counter=$((counter +1))
fi

#
# A record search with not existing domain.
#

set +e
get_record_value 'A' 'dns.xxxxxx.it.' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected, hosted zone not found.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing get_record_value with A record and not existing domain.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

if test -n "${record_value}"
then
  echo 'ERROR: testing get_record_value A record search with not existing domain.'
  counter=$((counter +1))
fi

#
# A record search with not fully qualified domain.
#

set -e
get_record_value 'A' 'dns.maxmin.it' > /dev/null 2>&1
exit_code=$?
set +e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_value with A record and not fully qualified domain.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

# An empty string is expected.
if test -n "${record_value}"
then
  echo 'ERROR: testing get_record_value NS record search with not fully qualified domain.'
  counter=$((counter +1))
fi

#
# NS record search with not existing domain.
#

set +e
get_record_value 'NS' 'xxx.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_value with NS record and not existing domain.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

# An empty string is expected.
if test -n "${record_value}"
then
  echo 'ERROR: testing get_record_value NS record search with not existing domain.'
  counter=$((counter +1))
fi

#
# NS record search with not fully qualified domain.
#

set +e
get_record_value 'NS' 'dns.maxmin.it' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_value with NS record and not fully qualified domain.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

# An empty string is expected.
if test -n "${record_value}"
then
  echo 'ERROR: testing get_record_value NS record search with not fully qualified domain.'
  counter=$((counter +1))
fi

#
# Wrong record type.
#

set +e
get_record_value 'CNAME' 'dns.maxmin.it' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_value with CNAME record.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

if test -n "${record_value}"
then
  echo 'ERROR: testing get_record_value with wrong record type.'
  counter=$((counter +1))
fi

#
# A record search with valid domain.
#

set +e
get_record_value 'A' 'dns.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_value with A record and valid domain.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

# Check the value.
if [[ '18.203.73.111' != "${record_value}" ]]
then
   echo 'ERROR: testing get_record_value with A record and valid domain.'
   counter=$((counter +1))
fi  

#
# NS record search with valid domain.
#

set +e
get_record_value 'NS' 'dns.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_value with NS record and valid domain.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

# Check the value.    
if [[ 'dns.maxmin.it.' != "${record_value}" ]]
then
   echo 'ERROR: testing get_record_value with NS record and valid domain.'
   counter=$((counter +1))
fi    

#
# aws-alias record search with valid domain.
#

set +e
get_record_value 'aws-alias' 'lbal.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_value with aws-record record and valid domain.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

# Check the value {AWS alias are A type records}.    
if [[ '1203266565.eu-west-1.elb.amazonaws.com.' != "${record_value}" ]]
then
   echo 'ERROR: testing get_record_value with aws-record record and valid domain.'
   counter=$((counter +1))
fi 

#
# aws-alias record search with not fully qualified domain.
#

set +e
get_record_value 'aws-alias' 'lbal.maxmin.it'    > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_value with aws-alias record and not fully qualified domain.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

if test -n "${record_value}"
then
   echo 'ERROR: testing get_record_value aws-alias record search with not fully qualified domain.'
   counter=$((counter +1))
fi
    
echo 'get_record_value tests completed.'

__helper_clear_resources > /dev/null 2>&1 


############################################
## TEST: __submit_change_batch
############################################

__helper_clear_resources > /dev/null 2>&1

#
# Missing parameter.
#

set +e
__submit_change_batch "${HOSTED_ZONE_ID}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __submit_change_batch with missing parameter.'
   counter=$((counter +1))
fi 

#
# Wrong request.
#

# Prepare the body of the request.
__create_alias_record_change_batch 'CREATE' 'lbal.xxx.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" \
    'load balancer record'
request_body="${__RESULT}"
     
set +e   
__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body}" > /dev/null 2>&1
exit_code=$?
set -e

# Error expected.
if test 0 -eq ""${exit_code}""
then
   echo 'ERROR: testing __submit_change_batch with wrong request.'
   counter=$((counter +1))
fi

#
# Valid request.
#

# Prepare the body of the request.
__create_alias_record_change_batch 'CREATE' 'lbal.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" \
    'load balancer record'
request_body="${__RESULT}"
    
set +e    
__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

# Check the value {AWS alias are A type records}.
record_value="$(aws route53 list-resource-record-sets \
    --hosted-zone-id "${HOSTED_ZONE_ID}" \
    --query "ResourceRecordSets[? Type == 'A' && Name == 'lbal.maxmin.it.' ].AliasTarget.DNSName" \
    --output text)"
    
if [[ '1203266565.eu-west-1.elb.amazonaws.com.' != "${record_value}" ]]
then
   echo 'ERROR: testing __submit_change_batch with aws-record record and valid domain.'
   counter=$((counter +1))
fi 

#
# Same request twice.
#

# An error is expected.
set +e
__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body}" > /dev/null 2>&1
exit_code=$?
set -e

if test 0 -eq ""${exit_code}""
then
   echo 'ERROR: testing __submit_change_batch twice.'
   counter=$((counter +1))
fi

__helper_clear_resources > /dev/null 2>&1 

echo '__submit_change_batch tests completed.'

#####################################################
## TEST: check_hosted_zone_has_loadbalancer_record
#####################################################

__helper_clear_resources > /dev/null 2>&1 

# Create an alias record. An alias record is an AWS extension of the DNS functionality, it is 
# inserted in the hosted zone as a type A record.    
__helper_create_alias_record \
    'lbal.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null  

#
# Missing argument.
#

set +e
check_hosted_zone_has_loadbalancer_record > /dev/null 2>&1
exit_code=$?
set -e

if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing check_hosted_zone_has_loadbalancer_record with missing argument.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
check_hosted_zone_has_loadbalancer_record 'lbal.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_loadbalancer_record.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

# Check the value.
if [[ 'true' != "${has_record}" ]]
then
   echo 'ERROR: testing check_hosted_zone_has_loadbalancer_record value.'
   counter=$((counter +1))
fi

echo 'check_hosted_zone_has_loadbalancer_record tests completed.'

#####################################################
## TEST: get_loadbalancer_record_hosted_zone_value
#####################################################

__helper_clear_resources > /dev/null 2>&1 

# Create an alias record. An alias record is an AWS extension of the DNS functionality, it is 
# inserted in the hosted zone as a type A record.    
__helper_create_alias_record \
    'lbal.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Missing argument.
#

set +e
get_loadbalancer_record_hosted_zone_value > /dev/null 2>&1
exit_code=$?
set -e

if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing get_loadbalancer_record_hosted_zone_value with missing argument.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
get_loadbalancer_record_hosted_zone_value 'lbal.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_loadbalancer_record_hosted_zone_value.'
   counter=$((counter +1))
fi

record_value="${__RESULT}"

# Check the value.
if [[ "${ALIAS_TARGET_HOSTED_ZONE_ID}" != "${record_value}" ]]
then
   echo 'ERROR: testing get_loadbalancer_record_hosted_zone_value value.'
   counter=$((counter +1))
fi

echo 'get_loadbalancer_record_hosted_zone_value tests completed.'

###########################################
## TEST: check_hosted_zone_has_record
###########################################

__helper_clear_resources > /dev/null 2>&1 

# Insert a dns.maxmin.it.maxmin.it NS and A records in the hosted zone.
__helper_create_record \
    'dns.maxmin.it.' \
    '18.203.73.111' \
    'A' > /dev/null 

__helper_create_record \
    'dns.maxmin.it.' \
    'dns.maxmin.it.' \
    'NS' > /dev/null 

# Create an alias record. An alias record is an AWS extension of the DNS functionality, it is 
# inserted in the hosted zone as a type A record.    
__helper_create_alias_record \
    'lbal.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Missing argument.
#

set +e
check_hosted_zone_has_record 'dns.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing check_hosted_zone_has_record with missing argument.'
   counter=$((counter +1))
fi

#
# A record search with not existing domain.
#

set +e
check_hosted_zone_has_record 'A' 'dns.xxxxxx.it.' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected, hosted zone not found.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with A record and not existing domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

# Empty value expected.
if test -n "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record A record search with not existing domain.'
  counter=$((counter +1))
fi

#
# A record search with empty domain.
#

set +e
check_hosted_zone_has_record 'A' '' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected, hosted zone not found.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with A record and empty domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

# Empty value expected.
if test -n "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record A record search with empty domain.'
  counter=$((counter +1))
fi

#
# A record search with not fully qualified domain.
#

set +e
check_hosted_zone_has_record 'A' 'lbal.maxmin.it' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with A record and not fully qualified domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record A record search with not fully qualified domain.'
  counter=$((counter +1))
fi

#
# NS record search with empty domain.
#

set +e
check_hosted_zone_has_record 'NS' '' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected, hosted zone not found.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with NS record and empty domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test -n "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record NS record search with empty domain.'
  counter=$((counter +1))
fi

#
# NS record search with not fully qualified domain.
#

set +e
check_hosted_zone_has_record 'NS' 'lbal.maxmin.it' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with NS record and not fully qualified domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record NS record search with not fully qualified domain.'
  counter=$((counter +1))
fi

#
# NS record search with not existing domain.
#

set +e
check_hosted_zone_has_record 'NS' 'xxx.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with NS record and not existing domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record NS record search with not existing domain.'
  counter=$((counter +1))
fi

#
# Wrong record type.
#

set +e
check_hosted_zone_has_record  'CNAME' 'dns.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with CNAME record.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record wrong record type.'
  counter=$((counter +1))
fi

#
# A record search with valid domain.
#

set +e
check_hosted_zone_has_record  'A' 'dns.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with A record and not valid domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test 'true' != "${has_record}"
then
   echo 'ERROR: testing check_hosted_zone_has_record A record search with valid domain.'
   counter=$((counter +1))
fi

#
# NS record search with valid domain.
#

set +e
check_hosted_zone_has_record  'NS' 'dns.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with NS record and valid domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test 'true' != "${has_record}"
then
   echo 'ERROR: testing check_hosted_zone_has_record NS record search with valid domain.'
   counter=$((counter +1))
fi

#
# aws-alias record search with valid domain.
#

set +e
check_hosted_zone_has_record  'aws-alias' 'lbal.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with aws-alias record and valid domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test 'true' != "${has_record}"
then
   echo 'ERROR: testing check_hosted_zone_has_record aws-alias record search with valid domain.'
   counter=$((counter +1))
fi

#
# aws-alias record search with not fully qualified domain.
#

set +e
check_hosted_zone_has_record  'aws-alias' 'lbal.maxmin.it' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_has_record with aws-record record and not not fully qualified domain.'
   counter=$((counter +1))
fi

has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
   echo 'ERROR: testing check_hosted_zone_has_record aws-alias record search with not fully qualified domain.'
   counter=$((counter +1))
fi
    
echo 'check_hosted_zone_has_record tests completed.'

__helper_clear_resources > /dev/null 2>&1 

###########################################
## TEST: get_hosted_zone_name_servers
###########################################

#
# Missing parameter.
#

set +e
get_hosted_zone_name_servers > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing get_hosted_zone_name_servers with missing parameter.'
   counter=$((counter +1))
fi

#
# Successful search.
#

get_hosted_zone_name_servers 'maxmin.it.' > /dev/null 2>&1
name_servers="${__RESULT}"

if test -z "${name_servers}" 
then
   echo 'ERROR: testing get_hosted_zone_name_servers with hosted zone name maxmin.it.'
   counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

set +e
get_hosted_zone_name_servers 'maxmin.it' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing get_hosted_zone_name_servers without trailing dot.'
   counter=$((counter +1))
fi

name_servers="${__RESULT}"

if test -n "${name_servers}" 
then
   echo 'ERROR: testing get_hosted_zone_name_servers without trailing dot, empty value expected.'
   counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

set +e
get_hosted_zone_name_servers '' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing get_hosted_zone_name_servers with empty hosted zone.'
   counter=$((counter +1))
fi

name_servers="${__RESULT}"

if [[ -n "${name_servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with empty hosted zone name.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

set +e
get_hosted_zone_name_servers 'xxxxx.it.' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing get_hosted_zone_name_servers withnot existing hosted zone.'
   counter=$((counter +1))
fi

name_servers="${__RESULT}"

if [[ -n "${name_servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with wrong hosted zone name.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

set +e
get_hosted_zone_name_servers 'it' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing get_hosted_zone_name_servers not existing hosted zone.'
   counter=$((counter +1))
fi

name_servers="${__RESULT}"

if [[ -n "${name_servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with not existing it hosted zone name.'
   counter=$((counter +1))
fi

echo 'get_hosted_zone_name_servers tests completed.'

###########################################
## TEST: __get_hosted_zone_id
###########################################

#
# Missing parameter.
#

set +e
__get_hosted_zone_id > /dev/null 2>&1
exit_code=$?
set -e

if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __get_hosted_zone_id with missing argument.'
   counter=$((counter +1))
fi

#
# Successful search.
#

set +e
__get_hosted_zone_id 'maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __get_hosted_zone_id.'
   counter=$((counter +1))
fi

hosted_zone_id="${__RESULT}" 

# Check the value.
if test "${HOSTED_ZONE_ID}" != "${hosted_zone_id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with correct hosted zone name.'
  counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

set +e
__get_hosted_zone_id 'maxmin.it' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __get_hosted_zone_id without trailing dot.'
   counter=$((counter +1))
fi

hosted_zone_id="${__RESULT}"

if test -n "${hosted_zone_id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with hosted zone name without trailing dot.'
  counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

set +e
__get_hosted_zone_id '' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __get_hosted_zone_id with empty hosted zone name.'
   counter=$((counter +1))
fi

hosted_zone_id="${__RESULT}"

if test -n "${hosted_zone_id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with empty hosted zone name.'
  counter=$((counter +1))
fi

#
# Wrong hosted zone name.
#

set +e
__get_hosted_zone_id 'xxx.maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __get_hosted_zone_id with wrong name.'
   counter=$((counter +1))
fi

hosted_zone_id="${__RESULT}"

if test -n "${hosted_zone_id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with wrong hosted zone name.'
  counter=$((counter +1))
fi

echo '__get_hosted_zone_id tests completed.'

###########################################
## TEST: __create_delete_record
###########################################

__helper_clear_resources > /dev/null 2>&1 

#
# Missing parameter.
#

set +e
__create_delete_record 'CREATE' 'A' 'dns.maxmin.it.' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __create_delete_record with missing parameter.'
   counter=$((counter +1))
fi

#
# Wrong action name.
#

set +e
__create_delete_record 'UPDATE' 'A' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __create_delete_record with wrong action name.'
   counter=$((counter +1))
fi

#
# Wrong record type.
#

set +e
__create_delete_record 'CREATE' 'CNAME' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __create_delete_record with wrong record type.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

set +e
__create_delete_record 'CREATE' 'A' 'dns.xxxxxx.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

request_id="${__RESULT}"

# An error is expected.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing __create_delete_record with not existing hosted zone.'
   counter=$((counter +1))
fi

# Empty string is expected.
if [[ -n "${request_id}" ]]
then
   echo 'ERROR: testing __create_delete_record with non existing hosted zone.'
   counter=$((counter +1))
fi

#
# Create type A record successfully.
#

set +e
__create_delete_record 'CREATE' 'A' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __create_delete_record creating type A record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record valid type A record.'
   counter=$((counter +1))
fi

# Check the record value.
value="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Type=='A' && Name=='dns.maxmin.it.' ].ResourceRecords[*].Value" \
   --output text)"
              
if [[ "${value}" != '18.203.73.111' ]]
then
   echo 'ERROR: testing __create_delete_record create type A record value.'
   counter=$((counter +1))
fi 

#
# Create twice the same type A record.
#

set +e
__create_delete_record 'CREATE' 'A' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing __create_delete_record create type A record twice.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Empty value expected.
if test -n "${request_id}"
then
   echo 'ERROR: testing __create_delete_record create type A record twice.'
   counter=$((counter +1))
fi

#
# Delete type A record successfully.
#

set +e
__create_delete_record 'DELETE' 'A' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __create_delete_record deleting type A record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record delete type A record with valid values.'
   counter=$((counter +1))
fi

#
# Delete type A record twice.
#

set +e
__create_delete_record 'DELETE' 'A' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

request_id="${__RESULT}"

# An error is expected.
if test "${exit_code}" -eq 0
then
   echo 'ERROR: testing __create_delete_record delete type A record twice.'
   counter=$((counter +1))
fi

# Empty value expected.
if test -n "${request_id}"
then
   echo 'ERROR: testing __create_delete_record delete type A record twice.'
   counter=$((counter +1))
fi

#
# Create NS type record successfully.
#

set +e
__create_delete_record 'CREATE' 'NS' 'dns.maxmin.it.' 'dns.maxmin.it.' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __create_delete_record creating NS type record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record create NS type record with valid values.'
   counter=$((counter +1))
fi

# Check the record value.
value="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Type=='NS' && Name=='dns.maxmin.it.' ].ResourceRecords[*].Value" \
   --output text)"
              
if [[ "${value}" != 'dns.maxmin.it.' ]]
then
   echo 'ERROR: testing __create_delete_record create NS type value.'
   counter=$((counter +1))
fi  

#
# Delete NS type record successfully.
#

set +e
__create_delete_record 'DELETE' 'NS' 'dns.maxmin.it.' 'dns.maxmin.it.' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __create_delete_record deleting NS type record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record delete NS type record with valid values.'
   counter=$((counter +1))
fi

#
# Create aws-alias type record successfully.
#

set +e
__create_delete_record 'CREATE' 'aws-alias' 'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __create_delete_record creating aws-type type record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"   

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record create aws-alias type record with valid values.'
   counter=$((counter +1))
fi

# Check the record value.
value="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='lbal.maxmin.it.'].AliasTarget.DNSName" \
   --output text)"
   
if [[ "${value}" != '1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing __create_delete_record create aws-alias type value.'
   counter=$((counter +1))
fi 

# Check the hosted zone ID value.
value="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='lbal.maxmin.it.' ].AliasTarget.HostedZoneId" \
   --output text)" 

if [[ "${value}" != "${ALIAS_TARGET_HOSTED_ZONE_ID}" ]]
then
   echo 'ERROR: testing __create_delete_record create aws-alias type targeted zone value.'
   counter=$((counter +1))
fi 

#
# Delete aws-alias type record successfully.
#

set +e
__create_delete_record 'DELETE' 'aws-alias' 'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
   "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __create_delete_record deleting aws-type type record.'
   counter=$((counter +1))
fi
   
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record delete aws-alias type record with valid values.'
   counter=$((counter +1))
fi

# Check the hosted zone has been cleared.
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='lbal.maxmin.it'].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing __create_delete_record DELETE record found in the hosted zone.'
   counter=$((counter +1))
fi 

echo '__create_delete_record tests completed.'

###########################################
## TEST: delete_record
###########################################

__helper_clear_resources > /dev/null 2>&1 

# Insert a dns.maxmin.it.maxmin.it NS and A records in the hosted zone.
__helper_create_record 'dns.maxmin.it.' '18.203.73.111' 'A' > /dev/null 
__helper_create_record 'dns.maxmin.it.' 'dns.maxmin.it.' 'NS' > /dev/null 

#
# Missing parameter.
#

set +e
delete_record  'A' 'dns.maxmin.it.' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing delete_record with missing parameter.'
   counter=$((counter +1))
fi

#
# Delete A record succesfully.
#

set +e
delete_record  'A' 'dns.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing delete_record with type A record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing delete_record request status value.'
   counter=$((counter +1))
fi

# Check the record has been cleared.
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='dns.maxmin.it' && Type=='A' ].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing delete_record deleting valid type A record.'
   counter=$((counter +1))
fi

#
# Not existing record.
#

set +e
delete_record  'A' 'xxx.maxmin.it.' '18.203.73.111' > /dev/null 2>&1 
exit_code=$?
set -e

if [[ 0 -eq ""${exit_code}"" ]]
then
   echo 'ERROR: testing delete_record deleting not existing A record.'
   counter=$((counter +1))
fi

#
# Delete NS record successfully.
#

set +e
delete_record  'NS' 'dns.maxmin.it.' 'dns.maxmin.it.' > /dev/null 2>&1 
exit_code=$?
set -e


# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing delete_record with NS type record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing delete_record request status value.'
   counter=$((counter +1))
fi

# Check the record has been cleared.
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='dns.maxmin.it' && Type=='A' ].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing delete_record valid NS type record.'
   counter=$((counter +1))
fi

echo 'delete_record tests completed.'

###########################################
## TEST: get_record_request_status
###########################################

__helper_clear_resources > /dev/null 2>&1 

# Create the record.
__helper_create_record 'dns.maxmin.it.' '18.203.73.111' 'A'     
request_id="${__RESULT}"

#
# Missing parameter.
#

set +e
get_record_request_status > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing get_record_request_status with missing parameter.'
   counter=$((counter +1))
fi
    
#
# Valid type A request search.
# 

set +e
get_record_request_status "${request_id}" > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_request_status with type A record.'
   counter=$((counter +1))
fi

status="${__RESULT}"

if [[ 'PENDING' != "${status}" && 'INSYNC' != "${status}" ]]
then
   echo 'ERROR: testing get_record_request_status with valid type A record request ID.'
   counter=$((counter +1))
fi

#
# Valid type aws-alias request search.
#

# Create the record. 
__helper_create_alias_record \
    'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}"    
request_id="${__RESULT}"

set +e
get_record_request_status "${request_id}" > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_record_request_status with type aws-alias record.'
   counter=$((counter +1))
fi

status="${__RESULT}"

if [[ 'PENDING' != "${status}" && 'INSYNC' != "${status}" ]]
then
   echo 'ERROR: testing get_record_request_status with valid alias record request ID.'
   counter=$((counter +1))
fi

#
# Not existing request.
#

# Check the status of a not existing requests.
set +e
get_record_request_status 'xxx' > /dev/null 2>&1 
exit_code=$? 
set -e

# An error is expected
if [[ 0 -eq ""${exit_code}"" ]]
then
   echo 'ERROR: testing get_record_request_status DELETE with not existing request.'  
fi

status="${__RESULT}"

# An empty string is expected
if test -n "${status}"
then
   echo 'ERROR: testing get_record_request_status with not existing request id.'
   counter=$((counter +1))
fi

echo 'get_record_request_status tests completed.'

###########################################
## TEST: delete_loadbalancer_record
###########################################

__helper_clear_resources > /dev/null 2>&1 
__helper_create_alias_record 'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
#
# Missing parameter.
#

set +e
delete_loadbalancer_record 'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing delete_loadbalancer_record with missing parameter.'
   counter=$((counter +1))
fi        

#
# Delete record successfully.
#

set +e
delete_loadbalancer_record 'lbal.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing delete_loadbalancer_record.'
   counter=$((counter +1))
fi

request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing delete_loadbalancer_record request status value.'
   counter=$((counter +1))
fi
    
# Check the hosted zone has been cleared.
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='lbal.maxmin.it' ].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing delete_loadbalancer_record valid load balancer record.'
   counter=$((counter +1))
fi 

# Delete a not existing record.
set +e
delete_loadbalancer_record 'xxx.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 2>&1 
exit_code=$? 
set -e

# An error is expected
if [[ 0 -eq ""${exit_code}"" ]]
then
   echo 'ERROR: testing delete_loadbalancer_record with not existing record.'  
fi

echo 'delete_loadbalancer_record tests completed.'

###########################################
## TEST: check_hosted_zone_exists
###########################################

#
# Missing parameter.
#

set +e
check_hosted_zone_exists > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing check_hosted_zone_exists with missing parameter.'
   counter=$((counter +1))
fi        

#
# Successful search.
#

set +e
check_hosted_zone_exists 'maxmin.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_exists.'
   counter=$((counter +1))
fi

exists="${__RESULT}"

if test 'true' != "${exists}"
then
   echo 'ERROR: testing check_hosted_zone_exists with correct hosted zone name.'
   counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

set +e
check_hosted_zone_exists 'maxmin.it' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_exists with hosted zone name without trailing dot.'
   counter=$((counter +1))
fi

exists="${__RESULT}"

if test 'false' != "${exists}"
then
   echo 'ERROR: testing check_hosted_zone_exists hosted zone name without trailing dot.'
   counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

set +e
check_hosted_zone_exists '' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_exists with empty hosted zone name.'
   counter=$((counter +1))
fi

exists="${__RESULT}"

if test 'false' != "${exists}" 
then
  echo 'ERROR: testing check_hosted_zone_exists empty hosted zone name.'
  counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

set +e
check_hosted_zone_exists 'xxxx.it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_exists with not existing hosted zone.'
   counter=$((counter +1))
fi

exists="${__RESULT}"

if 'false' != "${exists}"
then
  echo 'ERROR: testing check_hosted_zone_exists with not existing hosted zone.'
  counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

set +e
check_hosted_zone_exists 'it.' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_hosted_zone_exists with not existing hosted zone.'
   counter=$((counter +1))
fi

exists="${__RESULT}"

if 'false' != "${exists}"
then
  echo 'ERROR: testing check_hosted_zone_exists with it hosted zone name.'
  counter=$((counter +1))
fi

echo 'check_hosted_zone_exists tests completed.'

################################################
## TEST: __create_record_change_batch
################################################

set +e
__create_record_change_batch 'CREATE' 'A' 'webphp1.maxmin.it.' '34.242.102.242' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __create_record_change_batch with missing parameter.'
   counter=$((counter +1))
fi

#
# Create a JSON request for a type A record.
#

__create_record_change_batch 'CREATE' 'A' 'webphp1.maxmin.it.' '34.242.102.242' 'admin website'
request_body="${__RESULT}"

## Validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${request_body}"
then
    # Get the comment element.
    comment="$(echo "${request_body}" | jq -r '.Comment')"
    
    if [[ 'admin website' != "${comment}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong comment element."
       counter=$((counter +1))
    fi
    
    # Get the action element.
    action="$(echo "${request_body}" | jq -r '.Changes[].Action')"
    
    if [[ 'CREATE' != "${action}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong action element."
       counter=$((counter +1))
    fi
    
    # Get the name element.
    name="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.Name')"
    
    if [[ 'webphp1.maxmin.it.' != "${name}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong name element."
       counter=$((counter +1))
    fi
    
    # Get the type element.
    type="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.Type')"
    
    if [[ 'A' != "${type}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong type element."
       counter=$((counter +1))
    fi
    
    # Get the ip element.
    ip="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.ResourceRecords[].Value')"
    
    if [[ '34.242.102.242' != "${ip}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong ip element."
       counter=$((counter +1))
    fi
else
    echo "Failed to parse JSON __create_record_change_batch request batch"
    counter=$((counter +1))
fi

#
# Create a JSON request for type NS record.
#

__create_record_change_batch 'CREATE' 'NS' 'dns.maxmin.it.' 'dns.maxmin.it.' 'admin website'
request_body="${__RESULT}"

## Validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${request_body}"
then
    # Get the comment element.
    comment="$(echo "${request_body}" | jq -r '.Comment')"
    
    if [[ 'admin website' != "${comment}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong comment element."
       counter=$((counter +1))
    fi
    
    # Get the action element.
    action="$(echo "${request_body}" | jq -r '.Changes[].Action')"
    
    if [[ 'CREATE' != "${action}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong action element."
       counter=$((counter +1))
    fi
    
    # Get the name element.
    name="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.Name')"
    
    if [[ 'dns.maxmin.it.' != "${name}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong name element."
       counter=$((counter +1))
    fi
    
    # Get the type element.
    type="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.Type')"
    
    if [[ 'NS' != "${type}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong type element."
       counter=$((counter +1))
    fi
    
    # Get the element value.
    value="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.ResourceRecords[].Value')"
    
    if [[ 'dns.maxmin.it.' != "${value}" ]]
    then
       echo "ERROR: testing __create_record_change_batch wrong element value."
       counter=$((counter +1))
    fi
else
    echo "Failed to parse JSON __create_record_change_batch request batch"
    counter=$((counter +1))
fi

echo '__create_record_change_batch tests completed.'

################################################
## TEST: __create_alias_record_change_batch
################################################

set +e
__create_alias_record_change_batch 'CREATE' 'lbal.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __create_alias_record_change_batch with missing parameter.'
   counter=$((counter +1))
fi

#
# Create a JSON request for a type aws-alias record.
#

__create_alias_record_change_batch 'CREATE' 'lbal.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" 'load balancer record'
request_body="${__RESULT}"

## Validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${request_body}"
then
    # Get the comment element.
    comment="$(echo "${request_body}" | jq -r '.Comment')"
    
    if [[ 'load balancer record' != "${comment}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong comment element."
       counter=$((counter +1))
    fi
    
    # Get the action element.
    action="$(echo "${request_body}" | jq -r '.Changes[].Action')"
    
    if [[ 'CREATE' != "${action}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong action element."
       counter=$((counter +1))
    fi
    
    # Get the name element.
    name="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.Name')"
    
    if [[ 'lbal.maxmin.it.' != "${name}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong name element."
       counter=$((counter +1))
    fi
    
    # Get the type element.
    type="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.Type')"
    
    if [[ 'A' != "${type}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong type element."
       counter=$((counter +1))
    fi
    
    # Get the hosted zone id element.
    hosted_zone_id="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.AliasTarget.HostedZoneId')"
    
    if [[ "${hosted_zone_id}" != "${ALIAS_TARGET_HOSTED_ZONE_ID}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong hosted_zone_id element."
    fi
    
    # Get the dns name element.
    dns_name="$(echo "${request_body}" | jq -r '.Changes[].ResourceRecordSet.AliasTarget.DNSName')"
    
    if [[ '1203266565.eu-west-1.elb.amazonaws.com.' != "${dns_name}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong dns_name element."
       counter=$((counter +1))
    fi        
else
    echo "ERROR: Failed to parse JSON __create_alias_record_change_batch request batch."
    counter=$((counter +1))
fi

echo '__create_alias_record_change_batch tests completed.'

__helper_clear_resources

##############################################
# Count the errors.
##############################################

echo

if [[ "${counter}" -gt 0 ]]
then
   echo "route53.sh script test completed with ${counter} errors."
else
   echo 'route53.sh script test successfully completed.'
fi

echo

exit 0

