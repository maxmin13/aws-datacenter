#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
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
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local domain_nm="${1}"
   local hosted_zone_id="${2}"
   local target_domain_nm="${3}"
   local target_hosted_zone_id="${4}"
   
   # Check the record has already been created.    
   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${hosted_zone_id}" \
       --query "ResourceRecordSets[? Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then
      echo 'ERROR: creating test aws-alias record, the record is alredy created.'
      return 1
   fi     
   
   __helper_create_delete_alias_record 'CREATE' "${domain_nm}" "${hosted_zone_id}" "${target_domain_nm}" "${target_hosted_zone_id}"
  
   return 0
}

#################################################
# Deletes aws-alias records.
################################################# 
function __helper_delete_alias_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local domain_nm="${1}"
   local hosted_zone_id="${2}"
   local target_domain_nm="${3}"
   local target_hosted_zone_id="${4}"
   
   # Check the record exists.    
   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${hosted_zone_id}" \
       --query "ResourceRecordSets[? Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then
      __helper_create_delete_alias_record 'DELETE' "${domain_nm}" "${hosted_zone_id}" "${target_domain_nm}" "${target_hosted_zone_id}"      
   fi    

   return 0
}

function __helper_create_delete_alias_record()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local action="${1}"
   local domain_nm="${2}"
   local hosted_zone_id="${3}"
   local target_domain_nm="${4}"
   local target_hosted_zone_id="${5}"
   local comment="${RECORD_COMMENT}"
   local template
   
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
  
   aws route53 change-resource-record-sets \
       --hosted-zone-id "${hosted_zone_id}" \
       --change-batch "${request_body}" \
       --query ChangeInfo.Id \
       --output text
   
   return 0
}

#################################################
# Creates A or NS records.
# Throws an error if the records is already created.
#################################################
function __helper_create_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local domain_nm="${1}"
   local hosted_zone_id="${2}"
   local record_value="${3}"
   local record_type="${4}"
   
   # Check the record has already been created.    
   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${hosted_zone_id}" \
       --query "ResourceRecordSets[? Type=='${record_type}' && Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then
      echo 'ERROR: creating test record, the record is alredy created.'
      return 1
   else
      __helper_create_delete_record 'CREATE' "${domain_nm}" "${hosted_zone_id}" "${record_value}" "${record_type}"  
   fi     
     
   return 0
}

#################################################
# Deletes A or NS records.
################################################# 
function __helper_delete_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local domain_nm="${1}"
   local hosted_zone_id="${2}"
   local record_value="${3}"
   local record_type="${4}"
   
   # Check the record exists.    
   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${hosted_zone_id}" \
       --query "ResourceRecordSets[? Type=='${record_type}' && Name=='${domain_nm}' ].Name" \
       --output text)" ]]
   then
      __helper_create_delete_record 'DELETE' "${domain_nm}" "${hosted_zone_id}" "${record_value}" "${record_type}"    
   fi    
   
   return 0
}

function __helper_create_delete_record()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local action="${1}"
   local domain_nm="${2}"
   local hosted_zone_id="${3}"
   local record_value="${4}"
   local record_type="${5}"
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
   
   aws route53 change-resource-record-sets \
       --hosted-zone-id "${hosted_zone_id}" \
       --change-batch "${request_body}" \
       --query ChangeInfo.Id \
       --output text    
   
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
# Successfull search.
#

id="$(__get_hosted_zone_id 'maxmin.it.')"

if test "/hostedzone/${HOSTED_ZONE_ID}" != "${id}" 
then
  echo 'ERROR: testing __get_hosted_zone_id with correct hosted zone name.'
  counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

if test -n "$(__get_hosted_zone_id 'maxmin.it')" 
then
  echo 'ERROR: testing __get_hosted_zone_id with hosted zone name without trailing dot.'
  counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

if test -n "$(__get_hosted_zone_id '')" 
then
  echo 'ERROR: testing __get_hosted_zone_id with empty hosted zone name.'
  counter=$((counter +1))
fi

#
# Wrong hosted zone name.
#

if test -n "$(__get_hosted_zone_id 'xxx.maxmin.it.')" 
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

if test 'true' != "$(check_hosted_zone_exists 'maxmin.it.')"
then
   echo 'ERROR: testing check_hosted_zone_exists with correct hosted zone name.'
   counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

if test 'false' != "$(check_hosted_zone_exists 'maxmin.it')"
then
   echo 'ERROR: testing check_hosted_zone_exists hosted zone name without trailing dot.'
   counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

if test 'false' != "$(check_hosted_zone_exists '')" 
then
  echo 'ERROR: testing check_hosted_zone_exists empty hosted zone name.'
  counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

if 'false' != "$(check_hosted_zone_exists 'xxx.maxmin.it')"
then
  echo 'ERROR: testing check_hosted_zone_exists with wrong hosted zone name.'
  counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

if 'false' != "$(check_hosted_zone_exists 'it')"
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

if test -z "$(get_hosted_zone_name_servers 'maxmin.it.')" 
then
   echo 'ERROR: testing get_hosted_zone_name_servers with hosted zone name maxmin.it.'
   counter=$((counter +1))
fi

#
# Hosted zone name without trailing dot.
#

if test -n "$(get_hosted_zone_name_servers 'maxmin.it')" 
then
   echo 'ERROR: testing get_hosted_zone_name_servers with hosted zone name maxmin.it.'
   counter=$((counter +1))
fi

#
# Empty hosted zone name.
#

servers="$(get_hosted_zone_name_servers '')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with empty hosted zone name.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

servers="$(get_hosted_zone_name_servers 'xxx.maxmin.it')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with wrong hosted zone name.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

servers="$(get_hosted_zone_name_servers 'it')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with it hosted zone name.'
   counter=$((counter +1))
fi

echo 'get_hosted_zone_name_servers tests completed.'

###########################################
## TEST 4: check_hosted_zone_has_record
###########################################

# Insert a acme-dns.maxmin.it.maxmin.it NS and A records in the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_create_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null 

__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

__helper_create_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

# Create an alias record. An alias record is an AWS extension of the DNS functionality, it is 
# inserted in the hosted zone as a type A record. 
__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
__helper_create_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Missing argument.
#

set +e
check_hosted_zone_has_record 'acme-dns' 'maxmin.it.' > /dev/null
exit_code=$?
set -e

if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing check_hosted_zone_has_record with missing argument.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone.
#

if test 'false' != "$(check_hosted_zone_has_record 'acme-dns' 'xxxxxx.it.' 'A')"
then
  echo 'ERROR: testing check_hosted_zone_has_record with wrong hosted zone.'
  counter=$((counter +1))
fi

#
# A record search with empty sub-domain.
#

if test 'false' != "$(check_hosted_zone_has_record '' 'maxmin.it.' 'A')"
then
  echo 'ERROR: testing check_hosted_zone_has_record searching type A record with empty subdomain.'
  counter=$((counter +1))
fi

#
# A record search with empty sub-domain and domain name without trailing dot.
#

if test 'false' != "$(check_hosted_zone_has_record '' 'maxmin.it' 'A')"
then
  echo 'ERROR: testing check_hosted_zone_has_record searching type A record with empty subdomain and domain name without trailing dot.'
  counter=$((counter +1))
fi

#
# Valid NS record search with empty sub-domain.
#

# The list of maxmin.it name servers is expected.
if test 'true' != "$(check_hosted_zone_has_record '' 'maxmin.it.' 'NS')"
then
  echo 'ERROR: testing check_hosted_zone_has_record searching type NS record with empty subdomain.'
  counter=$((counter +1))
fi

#
# NS record search with empty sub-domain and domain name without trailing dot.
#

# An empty string is expected.
if test 'false' != "$(check_hosted_zone_has_record '' 'maxmin.it' 'NS')"
then
  echo 'ERROR: testing check_hosted_zone_has_record searching type NS record with empty subdomain and domain name without trailing dot.'
  counter=$((counter +1))
fi

#
# Not existing sub-domain.
#

if test 'false' != "$(check_hosted_zone_has_record 'xxx' 'maxmin.it.' 'A')"
then
  echo 'ERROR: testing check_hosted_zone_has_record with non existing sub-domain.'
  counter=$((counter +1))
fi

#
# Wrong record type.
#

if test 'false' != "$(check_hosted_zone_has_record 'acme-dns' 'maxmin.it.' 'CNAME')"
then
  echo 'ERROR: testing check_hosted_zone_has_record with wrong record type.'
  counter=$((counter +1))
fi

#
# Valid A record search.
#

if test 'true' != "$(check_hosted_zone_has_record 'acme-dns' 'maxmin.it.' 'A')"
then
   echo 'ERROR: testing check_hosted_zone_has_record with valid A type search parameters.'
   counter=$((counter +1))
fi

#
# Valid type A record search and domain name without trailing dot.
#

if test 'false' != "$(check_hosted_zone_has_record 'acme-dns' 'maxmin.it' 'A')"
then
   echo 'ERROR: testing check_hosted_zone_has_record searching type A record with valid parameters and domain name without trailing dot.'
   counter=$((counter +1))
fi

#
# Valid NS record search.
#

if test 'true' != "$(check_hosted_zone_has_record 'acme-dns' 'maxmin.it.' 'NS')"
then
   echo 'ERROR: testing check_hosted_zone_has_record with valid NS type search parameters.'
   counter=$((counter +1))
fi

#
# NS record search with domain name without trailing dot.
#

if test 'false' != "$(check_hosted_zone_has_record 'acme-dns' 'maxmin.it' 'NS')"
then
   echo 'ERROR: testing check_hosted_zone_has_record searching type NS record with valid parameters and domain name without trailing dot.'
   counter=$((counter +1))
fi

#
# Valid aws-alias record search.
#

if test 'true' != "$(check_hosted_zone_has_record 'www' 'maxmin.it.' 'aws-alias')"
then
   echo 'ERROR: testing check_hosted_zone_has_record with valid alias record parameters.'
   counter=$((counter +1))
fi

#
# aws-alias record search with domain name without trailing dot.
#

if test 'false' != "$(check_hosted_zone_has_record 'www' 'maxmin.it' 'aws-alias')"
then
   echo 'ERROR: testing check_hosted_zone_has_record searching type aws-alias record with valid parameters and domain name without trailing dot.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_delete_record \
    'acme-dns.maxmin.it' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it' \
    'NS' > /dev/null

__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
echo 'check_hosted_zone_has_record tests completed.'

###########################################
## TEST 5: get_record_value
###########################################

# Insert a acme-dns.maxmin.it.maxmin.it NS and A records in the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_create_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null 

__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

__helper_create_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

# Create an alias record. An alias record is an AWS extension of the DNS functionality, it is 
# inserted in the hosted zone as a type A record. 
__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
__helper_create_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Missing argument.
#

set +e
get_record_value 'acme-dns' 'maxmin.it.' > /dev/null
exit_code=$?
set -e

if test 0 -eq "${exit_code}"
then
   echo 'ERROR: testing get_record_value with missing argument.'
   counter=$((counter +1))
fi

#
# Not existing hosted zone name.
#

if test -n "$(get_record_value 'acme-dns' 'xxxxxx.it.' 'A')"
then
  echo 'ERROR: testing get_record_value with wrong hosted zone.'
  counter=$((counter +1))
fi

#
# A record search with empty sub-domain.
#

if test -n "$(get_record_value '' 'maxmin.it.' 'A')"
then
  echo 'ERROR: testing get_record_value searching type A record with empty subdomain.'
  counter=$((counter +1))
fi

#
# NS record search with empty sub-domain.
#

# The list of maxmin.it name servers is expected.
if test -z "$(get_record_value '' 'maxmin.it.' 'NS')"
then
  echo 'ERROR: testing get_record_value searching type NS record with empty subdomain.'
  counter=$((counter +1))
fi

#
# NS record search with empty sub-domain and domain name without trailing dot.
#

# An empty string is expected.
if test -n "$(get_record_value '' 'maxmin.it' 'NS')"
then
  echo 'ERROR: testing get_record_value searching type NS record with empty subdomain and domain name without trailing dot.'
  counter=$((counter +1))
fi

#
# Not existing sub-domain.
#

if test -n "$(get_record_value 'xxx' 'maxmin.it.' 'A')"
then
  echo 'ERROR: testing get_record_value with non existing sub-domain.'
  counter=$((counter +1))
fi

#
# Wrong record type.
#

if test -n "$(get_record_value 'acme-dns' 'maxmin.it.' 'CNAME')"
then
  echo 'ERROR: testing get_record_value with wrong record type.'
  counter=$((counter +1))
fi

#
# Valid A record search.
#

if test -z "$(get_record_value 'acme-dns' 'maxmin.it.' 'A')"
then
   echo 'ERROR: testing get_record_value with valid A type search parameters.'
   counter=$((counter +1))
fi

#
# Valid A record search with domain name without trailing dot.
#

if test -n "$(get_record_value 'acme-dns' 'maxmin.it' 'A')"
then
   echo 'ERROR: testing get_record_value searching type A record with valid parameters and domain name without trailing dot.'
   counter=$((counter +1))
fi

#
# Valid NS record search.
#

if test -z "$(get_record_value 'acme-dns' 'maxmin.it.' 'NS')"
then
   echo 'ERROR: testing get_record_value with valid NS type search parameters.'
   counter=$((counter +1))
fi

#
# Valid NS record search with domain name without trailing dot.
#

if test -n "$(get_record_value 'acme-dns' 'maxmin.it' 'NS')"
then
   echo 'ERROR: testing get_record_value searching type NS record with valid parameters and domain name without trailing dot.'
   counter=$((counter +1))
fi

#
# Valid aws-alias record search.
#

if test -z "$(get_record_value 'www' 'maxmin.it.' 'aws-alias')"
then
   echo 'ERROR: testing get_record_value with valid alias record parameters.'
   counter=$((counter +1))
fi

#
# Valid aws-alias record search with domain name without trailing dot.
#

if test -n "$(get_record_value 'www' 'maxmin.it' 'aws-alias')"
then
   echo 'ERROR: testing get_record_value searching type aws-alias record with valid parameters and domain name without trailing dot.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_delete_record \
    'acme-dns.maxmin.it' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it' \
    'NS' > /dev/null

__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
echo 'get_record_value tests completed.'

################################################
## TEST 6: __create_record_change_batch
################################################

#
# Create a JSON request for a type A record.
#

request_body=''
request_body="$(__create_record_change_batch 'CREATE' 'A' 'webphp1.maxmin.it.' '34.242.102.242' 'admin website')"

## First validate JSON.
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

request_body=''
request_body="$(__create_record_change_batch 'CREATE' 'NS' 'acme-dns.maxmin.it.' 'acme-dns.maxmin.it.' 'admin website')"

## First validate JSON.
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

request_body=''
request_body="$(__create_alias_record_change_batch 'CREATE' 'www.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" 'load balancer record')"

## First validate JSON.
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

# Clear the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
#
# Missing parameter.
#

set +e
__create_delete_record 'CREATE' 'A' 'acme-dns' 'maxmin.it.' > /dev/null
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
__create_delete_record 'UPDATE' 'A' 'acme-dns' 'maxmin.it.' '18.203.73.111' > /dev/null
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
__create_delete_record 'CREATE' 'CNAME' 'acme-dns' 'maxmin.it.' '18.203.73.111' > /dev/null
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

set +e
__create_delete_record 'CREATE' 'A' 'acme-dns' 'xxxxxx.it.' '18.203.73.111' > /dev/null
exit_code=$?
set -e

# An error is expected.
if test $exit_code -eq 0
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
request_id="$(__create_delete_record 'CREATE' 'A' 'acme-dns' 'maxmin.it.' '18.203.73.111')"

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

# Delete the record.
request_id="$(__create_delete_record 'CREATE' 'A' 'acme-dns' 'maxmin.it.' '18.203.73.111')"

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
request_id="$(__create_delete_record 'DELETE' 'A' 'acme-dns' 'maxmin.it.' '18.203.73.111')"

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
request_id="$(__create_delete_record 'DELETE' 'A' 'acme-dns' 'maxmin.it.' '18.203.73.111')"

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
request_id="$(__create_delete_record 'CREATE' 'NS' 'acme-dns' 'maxmin.it.' 'acme-dns.maxmin.it.')"

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
request_id="$(__create_delete_record 'DELETE' 'NS' 'acme-dns' 'maxmin.it.' 'acme-dns.maxmin.it.')"

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
request_id="$(__create_delete_record 'CREATE' 'aws-alias' 'www' 'maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}")"

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
   --query "ResourceRecordSets[? Name=='www.maxmin.it.' ].AliasTarget.DNSName" \
   --output text)"
   
if [[ "${value}" != '1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing __create_delete_record create aws-alias type value.'
   counter=$((counter +1))
fi 

value=''  

# Check the hosted zone ID.
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
request_id="$(__create_delete_record 'DELETE' 'aws-alias' 'www' 'maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}")"

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
   --query "ResourceRecordSets[? Name=='www.maxmin.it' ].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing __create_delete_record DELETE record found in the hosted zone.'
   counter=$((counter +1))
fi 

echo '__create_delete_record tests completed.'

###########################################
## TEST 9: get_record_request_status
###########################################

# Clear the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
#
# Valid type A request search.
#

request_id=''
status='' 

# Create the record.
request_id="$(__create_delete_record 'CREATE' 'A' 'acme-dns' 'maxmin.it.' '18.203.73.111')"

# Check the request.
status="$(get_record_request_status "${request_id}")"

if [[ 'PENDING' != "${status}" && 'INSYNC' != "${status}" ]]
then
   echo 'ERROR: testing get_record_request_status with valid request ID.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

#
# Valid type aws-alias request search.
#

request_id=''
status=''    

# Create the record.
request_id="$(__create_delete_record 'CREATE' 'aws-alias' 'www' 'maxmin.it.' '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}")"

# Check the status of the request.
status="$(get_record_request_status "${request_id}")"

if [[ 'PENDING' != "${status}" && 'INSYNC' != "${status}" ]]
then
   echo 'ERROR: testing get_record_request_status with valid alias request ID.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
#
# Not existing request.
#

status=''

# Check the status of a not existing requests.
status="$(get_record_request_status 'xxx')"

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

# Clear the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Submit valid request.
#

request_body=''
request_id=''
status=''

# Prepare the body of the request.
request_body="$(__create_alias_record_change_batch 'CREATE' 'www.maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' "${ALIAS_TARGET_HOSTED_ZONE_ID}" \
    'load balancer record')"
    
# Subimt the request.    
request_id="$(__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body}")"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

echo '__submit_change_batch tests completed.'

###########################################
## TEST 11: create_loadbalancer_record
###########################################

# Clear the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

#
# Create load balancer record successfully.
#

request_id=''
status=''
value=''

# Create the record.
request_id="$(create_loadbalancer_record \
    'www' \
    'maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}")"

# Check the status of the request.
status="$(aws route53 get-change --id "${request_id}" --query ChangeInfo.Status --output text)"

if [[ "${status}" != 'INSYNC' && "${status}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 

echo 'create_loadbalancer_record tests completed.'

# Clear hosted zone.
__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
###########################################
## TEST 12: delete_loadbalancer_record
###########################################

# Clear the hosted zone.
__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '18.203.73.111' \
    'A' > /dev/null

__helper_delete_record \
    'acme-dns.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    'acme-dns.maxmin.it.' \
    'NS' > /dev/null 

__helper_delete_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null 
    
__helper_create_alias_record \
    'www.maxmin.it.' \
    "${HOSTED_ZONE_ID}" \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}" > /dev/null     

#
# Delete load balancer record successfully.
#

request_id=''
status=''
value=''

# Delete the record.
request_id="$(delete_loadbalancer_record \
    'www' \
    'maxmin.it.' \
    '1203266565.eu-west-1.elb.amazonaws.com.' \
    "${ALIAS_TARGET_HOSTED_ZONE_ID}")"

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

##############################################
# Count the errors.
##############################################

if [[ "${counter}" -gt 0 ]]
then
   echo "route53.sh script test completed with ${counter} errors."
else
   echo 'route53.sh script test successfully completed.'
fi

