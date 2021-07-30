#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
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

   local domain_nm="${1}"
   local target_domain_nm="${2}"
   local target_hosted_zone_id="${3}"
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
   
   eval "__RESULT='${request_id}'"
   
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

   local domain_nm="${1}"
   local target_domain_nm="${2}"
   local target_hosted_zone_id="${3}"
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
   
   eval "__RESULT='${request_id}'"   

   return 0
}

function __helper_create_delete_alias_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local action="${1}"
   local domain_nm="${2}"
   local target_domain_nm="${3}"
   local target_hosted_zone_id="${4}"
   local comment="${RECORD_COMMENT}"
   local template=''
   local request_id=''
   
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
   
   eval "__RESULT='${request_id}'"
   
   return 0
}

#################################################
# Creates A or NS records.
# Throws an error if the records is already created.
#################################################
function __helper_create_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local domain_nm="${1}"
   local record_value="${2}"
   local record_type="${3}"
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
   
   eval "__RESULT='${request_id}'"
    
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

   local domain_nm="${1}"
   local record_value="${2}"
   local record_type="${3}"
   local request_id=''

   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[? Type=='${record_type}' && Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then   
       __helper_create_delete_record 'DELETE' "${domain_nm}" "${record_value}" "${record_type}" 
       request_id="${__RESULT}"
   fi
    
   eval "__RESULT='${request_id}'"    
   
   return 0
}

function __helper_create_delete_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local action="${1}"
   local domain_nm="${2}"
   local record_value="${3}"
   local record_type="${4}"
   local comment="${RECORD_COMMENT}"
   local template=''
   
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
   
   eval "__RESULT='${request_id}'"       
   
   return 0
} 

function __clear_hosted_zone()
{
   __helper_delete_record \
       'acme-dns.maxmin.it.' '18.203.73.111' 'A' > /dev/null

   __helper_delete_record \
       'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.' 'NS' > /dev/null 

   __helper_delete_alias_record \
       'www.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
       "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
        
   return 0
}

##
##
##
echo 'Starting route53.sh script tests ...'
echo
##
##
##

###########################################
## TEST 1: __get_hosted_zone_id
###########################################

#
# Missing parameter.
#

set +e
__get_hosted_zone_id > /dev/null
exit_code=$?
set -e

if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing __get_hosted_zone_id with missing argument.'
   counter=$((counter +1))
fi

#
# Successfull search.
#

__get_hosted_zone_id 'maxmin.it.'
hosted_zone_id="${__RESULT}" 

if test "/hostedzone/${HOSTED_ZONE_ID}" != "${hosted_zone_id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with correct hosted zone name.'
  counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

__get_hosted_zone_id 'maxmin.it'
hosted_zone_id="${__RESULT}"

if test -n "${hosted_zone_id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with hosted zone name without trailing dot.'
  counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

__get_hosted_zone_id ''
hosted_zone_id="${__RESULT}"

if test -n "${hosted_zone_id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with empty hosted zone name.'
  counter=$((counter +1))
fi

#
# Wrong hosted zone name.
#

__get_hosted_zone_id 'xxx.maxmin.it.'
hosted_zone_id="${__RESULT}"

if test -n "${hosted_zone_id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with wrong hosted zone name.'
  counter=$((counter +1))
fi

echo '__get_hosted_zone_id tests completed.'

###########################################
## TEST 2: check_hosted_zone_exists
###########################################

#
# Successful search.
#

exists=''

check_hosted_zone_exists 'maxmin.it.'
exists="${__RESULT}"

if test 'true' != "${exists}"
then
   echo 'ERROR: testing check_hosted_zone_exists with correct hosted zone name.'
   counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

exists=''

check_hosted_zone_exists 'maxmin.it'
exists="${__RESULT}"

if test 'false' != "${exists}"
then
   echo 'ERROR: testing check_hosted_zone_exists hosted zone name without trailing dot.'
   counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

exists=''

check_hosted_zone_exists ''
exists="${__RESULT}"

if test 'false' != "${exists}" 
then
  echo 'ERROR: testing check_hosted_zone_exists empty hosted zone name.'
  counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

exists=''

check_hosted_zone_exists 'xxxx.it.'
exists="${__RESULT}"

if 'false' != "${exists}"
then
  echo 'ERROR: testing check_hosted_zone_exists with wrong hosted zone name.'
  counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

exists=''

check_hosted_zone_exists 'it.'
exists="${__RESULT}"

if 'false' != "${exists}"
then
  echo 'ERROR: testing check_hosted_zone_exists with it hosted zone name.'
  counter=$((counter +1))
fi

echo 'check_hosted_zone_exists tests completed.'

###########################################
## TEST 3: get_hosted_zone_name_servers
###########################################

#
# Successful search.
#

name_servers=''

get_hosted_zone_name_servers 'maxmin.it.'
name_servers="${__RESULT}"

if test -z "${name_servers}" 
then
   echo 'ERROR: testing get_hosted_zone_name_servers with hosted zone name maxmin.it.'
   counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

name_servers=''

get_hosted_zone_name_servers 'maxmin.it'
name_servers="${__RESULT}"

if test -n "${name_servers}" 
then
   echo 'ERROR: testing get_hosted_zone_name_servers with hosted zone name maxmin.it.'
   counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

name_servers=''

get_hosted_zone_name_servers ''
name_servers="${__RESULT}"

if [[ -n "${name_servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with empty hosted zone name.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

name_servers=''

get_hosted_zone_name_servers 'xxxxx.it.'
name_servers="${__RESULT}"

if [[ -n "${name_servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with wrong hosted zone name.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

name_servers=''

get_hosted_zone_name_servers 'it'
name_servers="${__RESULT}"

if [[ -n "${name_servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with it hosted zone name.'
   counter=$((counter +1))
fi

echo 'get_hosted_zone_name_servers tests completed.'

###########################################
## TEST 4: check_hosted_zone_has_record
###########################################

__clear_hosted_zone

# Insert a acme-dns.maxmin.it.maxmin.it NS and A records in the hosted zone.
__helper_create_record \
    'acme-dns.maxmin.it.' \
    '18.203.73.111' \
    'A' > /dev/null 

__helper_create_record \
    'acme-dns.maxmin.it.' \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

# Create an alias record. An alias record is an AWS extension of the DNS functionality, it is 
# inserted in the hosted zone as a type A record.    
__helper_create_alias_record \
    'www.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Missing argument.
#

set +e
check_hosted_zone_has_record 'acme-dns.maxmin.it.' > /dev/null
exit_code=$?
set -e

if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing check_hosted_zone_has_record with missing argument.'
   counter=$((counter +1))
fi

#
# A record search with not existing domain.
#

has_record=''

check_hosted_zone_has_record 'A' 'acme-dns.xxxxxx.it.'
has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record A record search with not existing domain.'
  counter=$((counter +1))
fi

#
# A record search with empty domain.
#

has_record=''

check_hosted_zone_has_record 'A' ''
has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record A record search with empty domain.'
  counter=$((counter +1))
fi

#
# A record search with not fully qualified domain.
#

has_record=''

check_hosted_zone_has_record 'A' 'www.maxmin.it'
has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record A record search with not fully qualified domain.'
  counter=$((counter +1))
fi

#
# NS record search with empty domain.
#

has_record=''

check_hosted_zone_has_record 'NS' ''
has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record NS record search with empty domain.'
  counter=$((counter +1))
fi

#
# NS record search with not fully qualified domain.
#

has_record=''

check_hosted_zone_has_record 'NS' 'www.maxmin.it'
has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record NS record search with not fully qualified domain.'
  counter=$((counter +1))
fi

#
# NS record search with not existing domain.
#

has_record=''

check_hosted_zone_has_record 'NS' 'xxx.maxmin.it.'
has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record NS record search with not existing domain.'
  counter=$((counter +1))
fi

#
# Wrong record type.
#

has_record=''

check_hosted_zone_has_record  'CNAME' 'acme-dns.maxmin.it.'
has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
  echo 'ERROR: testing check_hosted_zone_has_record wrong record type.'
  counter=$((counter +1))
fi

#
# A record search with valid domain.
#

has_record=''

check_hosted_zone_has_record  'A' 'acme-dns.maxmin.it.'
has_record="${__RESULT}"

if test 'true' != "${has_record}"
then
   echo 'ERROR: testing check_hosted_zone_has_record A record search with valid domain.'
   counter=$((counter +1))
fi

#
# NS record search with valid domain.
#

has_record=''

check_hosted_zone_has_record  'NS' 'acme-dns.maxmin.it.'
has_record="${__RESULT}"

if test 'true' != "${has_record}"
then
   echo 'ERROR: testing check_hosted_zone_has_record NS record search with valid domain.'
   counter=$((counter +1))
fi

#
# aws-alias record search with valid domain.
#

has_record=''

check_hosted_zone_has_record  'aws-alias' 'www.maxmin.it.'
has_record="${__RESULT}"

if test 'true' != "${has_record}"
then
   echo 'ERROR: testing check_hosted_zone_has_record aws-alias record search with valid domain.'
   counter=$((counter +1))
fi

#
# aws-alias record search with not fully qualified domain.
#

has_record=''

check_hosted_zone_has_record  'aws-alias' 'www.maxmin.it'
has_record="${__RESULT}"

if test 'false' != "${has_record}"
then
   echo 'ERROR: testing check_hosted_zone_has_record aws-alias record search with not fully qualified domain.'
   counter=$((counter +1))
fi
    
echo 'check_hosted_zone_has_record tests completed.'

__clear_hosted_zone

###########################################
## TEST 5: get_record_value
###########################################

__clear_hosted_zone

# Insert a acme-dns.maxmin.it.maxmin.it NS and A records in the hosted zone.
__helper_create_record \
    'acme-dns.maxmin.it.' '18.203.73.111' 'A' > /dev/null 

__helper_create_record \
    'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.' 'NS' > /dev/null 

__helper_create_alias_record \
    'www.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Missing argument.
#

set +e
get_record_value 'acme-dns.maxmin.it.' > /dev/null
exit_code=$?
set -e

if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing get_record_value with missing argument.'
   counter=$((counter +1))
fi

#
# A record search with not existing domain.
#

record_value=''

get_record_value 'A' 'acme-dns.xxxxxx.it.'
record_value="${__RESULT}"

if test -n "${record_value}"
then
  echo 'ERROR: testing get_record_value A record search with not existing domain.'
  counter=$((counter +1))
fi

#
# A record search with not fully qualified domain.
#

record_value=''

get_record_value 'A' 'acme-dns.maxmin.it'
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

record_value=''

get_record_value 'NS' 'xxx.maxmin.it.'
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

record_value=''

get_record_value 'NS' 'acme-dns.maxmin.it'
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

record_value=''

get_record_value 'CNAME' 'acme-dns.maxmin.it'
record_value="${__RESULT}"

if test -n "${record_value}"
then
  echo 'ERROR: testing get_record_value with wrong record type.'
  counter=$((counter +1))
fi

#
# A record search with valid domain.
#

record_value=''

get_record_value 'A' 'acme-dns.maxmin.it.'
record_value="${__RESULT}"

if test -z "${record_value}"
then
   echo 'ERROR: testing get_record_value record search with valid domain.'
   counter=$((counter +1))
fi

#
# NS record search with valid domain.
#

record_value=''

get_record_value 'NS' 'acme-dns.maxmin.it.'
record_value="${__RESULT}"

if test -z "${record_value}"
then
   echo 'ERROR: testing get_record_value with valid NS type search parameters.'
   counter=$((counter +1))
fi

#
# aws-alias record search with valid domain.
#

record_value=''

get_record_value 'aws-alias' 'www.maxmin.it.'
record_value="${__RESULT}"

if test -z "${record_value}"
then
   echo 'ERROR: testing get_record_value aws-alias record search with valid domain.'
   counter=$((counter +1))
fi

#
# aws-alias record search with not fully qualified domain.
#

record_value=''

get_record_value 'aws-alias' 'www.maxmin.it'
record_value="${__RESULT}"

if test -n "${record_value}"
then
   echo 'ERROR: testing get_record_value aws-alias record search with not fully qualified domain.'
   counter=$((counter +1))
fi
    
echo 'get_record_value tests completed.'

__clear_hosted_zone

################################################
## TEST 6: __create_record_change_batch
################################################

#
# Create a JSON request for a type A record.
#

request_body=''
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

__create_record_change_batch 'CREATE' 'NS' 'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.' 'admin website'
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
    
    if [[ 'acme-dns.maxmin.it.' != "${name}" ]]
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
    
    if [[ 'acme-dns.maxmin.it.' != "${value}" ]]
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
## TEST 7: __create_alias_record_change_batch
################################################

#
# Create a JSON request for a type aws-alias record.
#

__create_alias_record_change_batch 'CREATE' 'www.maxmin.it.' \
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
    
    if [[ 'www.maxmin.it.' != "${name}" ]]
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

###########################################
## TEST 8: __create_delete_record
###########################################

__clear_hosted_zone
    
#
# Missing parameter.
#

set +e
__create_delete_record 'CREATE' 'A' 'acme-dns.maxmin.it.' > /dev/null
exit_code=$?
set -e

# An error is expected.
if test $exit_code -eq 0
then
   echo 'ERROR: testing __create_delete_record with missing parameter.'
   counter=$((counter +1))
fi

#
# Wrong action name.
#

set +e
__create_delete_record 'UPDATE' 'A' 'acme-dns.maxmin.it.' '18.203.73.111' > /dev/null
exit_code=$?
set -e

# An error is expected.
if test $exit_code -eq 0
then
   echo 'ERROR: testing __create_delete_record with wrong action name.'
   counter=$((counter +1))
fi

#
# Wrong record type.
#

set +e
__create_delete_record 'CREATE' 'CNAME' 'acme-dns.maxmin.it.' '18.203.73.111' > /dev/null
exit_code=$?
set -e

# An error is expected.
if test $exit_code -eq 0
then
   echo 'ERROR: testing __create_delete_record with wrong record type.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

__create_delete_record 'CREATE' 'A' 'acme-dns.xxxxxx.it.' '18.203.73.111'
request_id="${__RESULT}"

# Empty string is expected.
if [[ -n "${request_id}" ]]
then
   echo 'ERROR: testing __create_delete_record with non existing hosted zone.'
   counter=$((counter +1))
fi

#
# Create A type record successfully.
#

request_id=''
status=''
value=''

# Create the record.
__create_delete_record 'CREATE' 'A' 'acme-dns.maxmin.it.' '18.203.73.111'
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record create A type record with valid values.'
   counter=$((counter +1))
fi

# Check the record value.
value="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Type=='A' && Name=='acme-dns.maxmin.it.' ].ResourceRecords[*].Value" \
   --output text)"
              
if [[ "${value}" != '18.203.73.111' ]]
then
   echo 'ERROR: testing __create_delete_record create A type value.'
   counter=$((counter +1))
fi 

#
# Create twice the same A record.
#

request_id=''
status=''
value=''

__create_delete_record 'CREATE' 'A' 'acme-dns.maxmin.it.' '18.203.73.111'
request_id="${__RESULT}"

# Empty value expected.
if test -n "${request_id}"
then
   echo 'ERROR: testing __create_delete_record create A type record twice.'
   counter=$((counter +1))
fi

#
# Delete A type record successfully.
#

request_id=''
status=''
value=''

# Delete the record.
__create_delete_record 'DELETE' 'A' 'acme-dns.maxmin.it.' '18.203.73.111'
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record delete A type record with valid values.'
   counter=$((counter +1))
fi

#
# Delete A type record twice.
#

request_id=''
status=''
value=''

# Delete the record.
__create_delete_record 'DELETE' 'A' 'acme-dns.maxmin.it.' '18.203.73.111'
request_id="${__RESULT}"

# Empty string is expected.
if test -n "${request_id}"
then
   echo 'ERROR: testing __create_delete_record delete A type record twice.'
   counter=$((counter +1))
fi

#
# Create NS type record successfully.
#

request_id=''
status=''
value=''

# Create the record.
__create_delete_record 'CREATE' 'NS' 'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.'
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
   --query "ResourceRecordSets[? Type=='NS' && Name=='acme-dns.maxmin.it.' ].ResourceRecords[*].Value" \
   --output text)"
              
if [[ "${value}" != 'acme-dns.maxmin.it.' ]]
then
   echo 'ERROR: testing __create_delete_record create NS type value.'
   counter=$((counter +1))
fi  

#
# Delete NS type record successfully.
#

request_id=''
status=''
value=''

# Delete the record.
__create_delete_record 'DELETE' 'NS' 'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.'
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

request_id=''
status=''
value=''

# Create the record.
__create_delete_record 'CREATE' 'aws-alias' 'www.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}"
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
   --query "ResourceRecordSets[? Name=='www.maxmin.it.'].AliasTarget.DNSName" \
   --output text)"
   
if [[ "${value}" != '1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing __create_delete_record create aws-alias type value.'
   counter=$((counter +1))
fi 

value=''  

# Check the hosted zone ID value.
value="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='www.maxmin.it.' ].AliasTarget.HostedZoneId" \
   --output text)" 

if [[ "${value}" != "${ALIAS_TARGET_HOSTED_ZONE_ID}" ]]
then
   echo 'ERROR: testing __create_delete_record create aws-alias type targeted zone value.'
   counter=$((counter +1))
fi 

#
# Delete aws-alias type record successfully.
#

request_id=''
status=''
value=''

# Delete the record.
__create_delete_record 'DELETE' 'aws-alias' 'www.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}"
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
   --query "ResourceRecordSets[? Name=='www.maxmin.it'].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing __create_delete_record DELETE record found in the hosted zone.'
   counter=$((counter +1))
fi 

echo '__create_delete_record tests completed.'

###########################################
## TEST 9: get_record_request_status
###########################################

__clear_hosted_zone
    
#
# Valid type A request search.
#

request_id=''
status='' 

###### TODO USE AN HELPER
# Create the record.
__helper_create_record 'acme-dns.maxmin.it.' '18.203.73.111' 'A'     
request_id="${__RESULT}"  

# Check the request.
get_record_request_status "${request_id}"
status="${__RESULT}"

if [[ 'PENDING' != "${status}" && 'INSYNC' != "${status}" ]]
then
   echo 'ERROR: testing get_record_request_status with valid request ID.'
   counter=$((counter +1))
fi

__clear_hosted_zone

#
# Valid type aws-alias request search.
#

request_id=''
status='' 

# Create the record. 
__helper_create_alias_record \
    'www.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}"    
request_id="${__RESULT}"

# Check the status of the request.
get_record_request_status "${request_id}"
status="${__RESULT}"

if [[ 'PENDING' != "${status}" && 'INSYNC' != "${status}" ]]
then
   echo 'ERROR: testing get_record_request_status with valid alias request ID.'
   counter=$((counter +1))
fi

__clear_hosted_zone

#
# Not existing request.
#

request_id=''
status='' 

# Check the status of a not existing requests.
get_record_request_status 'xxx'
status="${__RESULT}"

# Empty string is expected.
if test -n "${status}"
then
   echo 'ERROR: testing get_record_request_status with not existing request id.'
   counter=$((counter +1))
fi

echo 'get_record_request_status tests completed.'

############################################
## TEST 10: __submit_change_batch
############################################

__clear_hosted_zone

#
# Submit valid request.
#

request_body=''
request_id=''
status=''

# Prepare the body of the request.
__create_alias_record_change_batch 'CREATE' 'www.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" \
    'load balancer record'
request_body="${__RESULT}"
    
# Subimt the request.    
__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body}"
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

#
# Submit the same request twice.
#

# Empty string is expected.

__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body}" > /dev/null 2>&1
request_id="$(__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body}")"

if [[ -n "${request_id}" ]]
then
   echo 'ERROR: testing __submit_change_batch twice.'
   counter=$((counter +1))
fi


__clear_hosted_zone

echo '__submit_change_batch tests completed.'

###########################################
## TEST 11: create_loadbalancer_record
###########################################

__clear_hosted_zone

#
# Create load balancer record successfully.
#

request_id=''
status=''
value=''

# Create the record.
create_loadbalancer_record \
    'www.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}"
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

echo 'create_loadbalancer_record tests completed.'

__clear_hosted_zone
    
###########################################
## TEST 12: delete_loadbalancer_record
###########################################

__clear_hosted_zone
    
__helper_create_alias_record \
    'www.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" \
    > /dev/null     

#
# Delete load balancer record successfully.
#

request_id=''
status=''
value=''

# Delete the record.
delete_loadbalancer_record \
    'www.maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}"
    
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi
    
# Check the hosted zone has been cleared.
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='www.maxmin.it' ].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing __create_delete_record DELETE record found in the hosted zone.'
   counter=$((counter +1))
fi     

echo 'delete_loadbalancer_record tests completed.'

###########################################
## TEST 13: create_record
###########################################

__clear_hosted_zone

#
# Create A record successfully.
#

request_id=''
status=''
value=''

# Create the record.
create_record  'A' 'acme-dns.maxmin.it.' '18.203.73.111'
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

#
# Create NS record successfully.
#

request_id=''
status=''
value=''

# Create the record.
create_record  'NS' 'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.'
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

echo 'create_record tests completed.'

__clear_hosted_zone

###########################################
## TEST 14: delete_record
###########################################

__clear_hosted_zone

# Insert a acme-dns.maxmin.it.maxmin.it NS and A records in the hosted zone.
__helper_create_record 'acme-dns.maxmin.it.' '18.203.73.111' 'A' > /dev/null 

__helper_create_record \
    'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.' 'NS' > /dev/null 

#
# Delete A record succesfully.
#

request_id=''
status=''

# Delete the record.
delete_record  'A' 'acme-dns.maxmin.it.' '18.203.73.111'
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

# Check the record has been cleared.
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='acme-dns.maxmin.it' && Type=='A' ].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing __create_delete_record DELETE record found in the hosted zone.'
   counter=$((counter +1))
fi

#
# Delete NS record successfully.
#

request_id=''
status=''

# Delete the record.
delete_record  'NS' 'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.'
request_id="${__RESULT}"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

# Check the record has been cleared.
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[? Name=='acme-dns.maxmin.it' && Type=='A' ].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing __create_delete_record DELETE record found in the hosted zone.'
   counter=$((counter +1))
fi

echo 'delete_record tests completed.'

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


