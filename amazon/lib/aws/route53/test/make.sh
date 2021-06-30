#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

HOSTED_ZONE_ID='/hostedzone/Z07357981HPLU4QUR6272'
NS1='ns-128.awsdns-16.com'   
NS2='ns-1930.awsdns-49.co.uk'
NS3='ns-752.awsdns-30.net'
NS4='ns-1095.awsdns-08.org'
RECORD_COMMENT="Type A test record"   
counter=0

##
## Functions used to handle test data.
##

#################################################
# Creates a www.maxmin.it alias record. 
#################################################
function __test_create_alias_record()
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
   
   # Check the record has already been created.    
   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[?contains(Name,'${domain_nm}')].Name" \
       --output text)" ]]
   then
      echo 'ERROR: creating test alias record, the record is alredy created.'
      return 1
   fi     
   
   request_id="$(__test_create_delete_alias_record 'CREATE' "${domain_nm}" "${target_domain_nm}" "${target_hosted_zone_id}")"   
       
   # Check the record has been created.    
   if [[ -z "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[?contains(Name,'${domain_nm}')].Name" \
       --output text)" ]]
   then
      echo 'ERROR: creating test alias record.'
      return 1
   fi 
   
   echo "${request_id}"
   
   return 0
}

#################################################
# Deletes a www.maxmin.it alias record.
################################################# 
function __test_delete_alias_record()
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
   
   # Check the record exists.    
   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[?contains(Name,'${domain_nm}')].Name" \
       --output text)" ]]
   then
      request_id="$(__test_create_delete_alias_record 'DELETE' "${domain_nm}" "${target_domain_nm}" "${target_hosted_zone_id}")"      
   fi    

   echo "${request_id}"
   
   return 0
}

function __test_create_delete_alias_record()
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
  
   ## Submit the changes.
   request_id="$(aws route53 change-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --change-batch "${request_body}" \
       --query ChangeInfo.Id \
       --output text)"
   
   echo "${request_id}"      
   
   return 0
}

#################################################
# Creates a www.maxmin.it alias record that 
# targets 18.203.73.111 address. 
#################################################
function __test_create_record()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local domain_nm="${1}"
   local ip_address="${2}"
   
   # Check the record has already been created.    
   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[?contains(Name,'${domain_nm}')].Name" \
       --output text)" ]]
   then
      echo 'ERROR: creating test record, the record is alredy created.'
      return 1
   fi     
   
   request_id="$(__test_create_delete_record 'CREATE' "${domain_nm}" "${ip_address}")"
       
   # Check the record has been created.    
   if [[ -z "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[?contains(Name,'${domain_nm}')].Name" \
       --output text)" ]]
   then
      echo 'ERROR: creating test record.'
      return 1
   fi 
   
   echo "${request_id}"
   
   return 0
}

#################################################
# Deletes a www.maxmin.it type A DNS record that 
# targets 18.203.73.111 address. 
################################################# 
function __test_delete_record()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local domain_nm="${1}"
   local ip_address="${2}"
   local request_id=''
   
   # Check the record exists.    
   if [[ -n "$(aws route53 list-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --query "ResourceRecordSets[?contains(Name,'${domain_nm}')].Name" \
       --output text)" ]]
   then
      request_id="$(__test_create_delete_record 'DELETE' "${domain_nm}" "${ip_address}")"      
   fi    

   echo "${request_id}"
   
   return 0
}

function __test_create_delete_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local action="${1}"
   local domain_nm="${2}"
   local ip_address="${3}"
   local comment="${RECORD_COMMENT}"
   local template
   local request_id
   
   template=$(cat <<-'EOF'
        {
           "Comment":"SEDcommentSED",
           "Changes":[
              {
                 "Action":"SEDactionSED",
                 "ResourceRecordSet":{
                    "Name":"SEDdomain_nameSED",
                    "Type":"A",
                    "TTL":120,
                    "ResourceRecords":[
                       {
                          "Value":"SEDip_addressSED"
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
             -e "s/SEDip_addressSED/${ip_address}/g" \
             -e "s/SEDcommentSED/${comment}/g" \
             -e "s/SEDactionSED/${action}/g")" 
   
   ## Submit the changes.
   request_id="$(aws route53 change-resource-record-sets \
       --hosted-zone-id "${HOSTED_ZONE_ID}" \
       --change-batch "${request_body}" \
       --query ChangeInfo.Id \
       --output text)"
   
   echo "${request_id}"      
   
   return 0
} 

##
##
##
echo 'Starting route53.sh script test ...'
echo
##
##
##

###########################################
## TEST 1: __get_hosted_zone_id
###########################################

if test "${HOSTED_ZONE_ID}" != "$(__get_hosted_zone_id 'maxmin.it')" 
then
  echo 'ERROR: testing __get_hosted_zone_id maxmin.it'
  counter=$((counter +1))
fi

if test -n "$(__get_hosted_zone_id '')" 
then
  echo 'ERROR: testing __get_hosted_zone_id <empty string>'
  counter=$((counter +1))
fi

if test -n "$(__get_hosted_zone_id 'xxx.maxmin.it')" 
then
  echo 'ERROR: testing __get_hosted_zone_id xxx.maxmin.it'
  counter=$((counter +1))
fi

echo '__get_hosted_zone_id tests completed.'

###########################################
## TEST 2: check_hosted_zone_exists
###########################################

if test 'true' != "$(check_hosted_zone_exists 'maxmin.it')"
then
   echo 'ERROR: testing check_hosted_zone_exists maxmin.it'
   counter=$((counter +1))
fi

if test 'false' != "$(check_hosted_zone_exists '')" 
then
  echo 'ERROR: testing check_hosted_zone_exists <empty string>'
  counter=$((counter +1))
fi

if 'false' != "$(check_hosted_zone_exists 'xxx.maxmin.it')"
then
  echo 'ERROR: testing check_hosted_zone_exists xxx.maxmin.it'
  counter=$((counter +1))
fi

if 'false' != "$(check_hosted_zone_exists 'it')"
then
  echo 'ERROR: testing check_hosted_zone_exists it'
  counter=$((counter +1))
fi

echo 'check_hosted_zone_exists tests completed.'

###########################################
## TEST 3: get_hosted_zone_name_servers
###########################################

# Successful search.
servers="$(get_hosted_zone_name_servers 'maxmin.it')"

if [[ "${servers}" != *"${NS1}"* || "${servers}" != *"${NS2}"* || \
      "${servers}" != *"${NS3}"* || "${servers}" != *"${NS4}"* ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with hosted zone name maxmin.it.'
   counter=$((counter +1))
fi

# Empty hosted zone name.
servers="$(get_hosted_zone_name_servers '')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers empty hosted zone name.'
   counter=$((counter +1))
fi

# Non existent hosted zone name.
servers="$(get_hosted_zone_name_servers 'xxx.maxmin.it')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with non existent hosted zone name xxx.maxmin.it.'
   counter=$((counter +1))
fi

# Non existent hosted zone name.
servers="$(get_hosted_zone_name_servers 'it')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers with non existent hosted zone name it.'
   counter=$((counter +1))
fi

echo 'get_hosted_zone_name_servers tests completed.'

###########################################
## TEST 4: __create_delete_record
###########################################

# Clear the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null  

# Send a wrong action name, error return code expected.
set +e
__create_delete_record 'UPDATE' 'www' 'maxmin.it' '18.203.73.111' >> /dev/null
exit_code=$?
set -e

# An error is expected.
if test $exit_code -eq 0
then
   echo 'ERROR: testing __create_delete_record with wrong action name.'
   counter=$((counter +1))
fi

# Non existent hosted zone name, empty request id expected.
request_id4a="$(__create_delete_record 'CREATE' 'www' 'xxxxxx.it' '18.203.73.111')"

if test -n "${request_id4a}"
then
   echo 'ERROR: testing __create_delete_record non existent hosted zone name.'
   counter=$((counter +1))
fi

# Insert www.maxmin.it record successfully, valid request id expected.
request_id4b="$(__create_delete_record 'CREATE' 'www' 'maxmin.it' '18.203.73.111')"
status4b="$(aws route53 get-change --id "${request_id4b}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status4b}" != 'INSYNC' && "${status4b}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record creating a record.'
   counter=$((counter +1))
fi

## Insert twice the same record, empty request id expected.
request_id4c="$(__create_delete_record 'CREATE' 'www' 'maxmin.it' '18.203.73.111')"

if test -n "${request_id4c}"
then
   echo 'ERROR: testing __create_delete_record creating twice a record.'
   counter=$((counter +1))
fi

# Delete www.maxmin.it successfully, valid request id expected.
request_id4d="$(__create_delete_record 'DELETE' 'www' 'maxmin.it' '18.203.73.111')"
status4d="$(aws route53 get-change --id "${request_id4d}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status4d}" != 'INSYNC' && "${status4d}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record DELETE deleting a record.'
   counter=$((counter +1))
fi

## Delete twice the same record, empty request id expected.
request_id4e="$(__create_delete_record 'DELETE' 'www' 'maxmin.it' '18.203.73.111')"

# Empty string is expected.
if test -n "${request_id4e}"
then
   echo 'ERROR: testing __create_delete_record DELETE deleting twice the same record.'
   counter=$((counter +1))
fi
         
# Check the hosted zone has been cleared.
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing __create_delete_record DELETE record found in the hosted zone.'
   counter=$((counter +1))
fi 

# Clear the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null 

echo '__create_delete_record tests completed.'

###########################################
## TEST 5: create_record
###########################################

# Clear the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null

# Create a record successfully, valid request id expected.
request_id5a="$(create_record 'www' 'maxmin.it' '18.203.73.111')"
status5a="$(aws route53 get-change --id "${request_id5a}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status5a}" != 'INSYNC' && "${status5a}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_record creating a record, wrong request status.'
   counter=$((counter +1))
fi

# Check the record target value.
ip5a="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].ResourceRecords[*].Value" \
   --output text)"
      
if [[ "${ip5a}" != '18.203.73.111' ]]
then
   echo 'ERROR: testing create_record wrong value found.'
   counter=$((counter +1))
fi  

# Clear the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null 

echo 'create_record tests completed.'

###########################################
## TEST 6: delete_record
###########################################

# Insert a www.maxmin.it (18.203.73.111) record in the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null
__test_create_record 'www.maxmin.it' '18.203.73.111' > /dev/null

# Delete a record successfully, valid request id expected.
request_id6a="$(delete_record 'www' 'maxmin.it' '18.203.73.111')"
status6a="$(aws route53 get-change --id "${request_id6a}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status6a}" != 'INSYNC' && "${status6a}" != 'PENDING' ]]
then
   echo 'ERROR: testing delete_delete_record deleting a record.'
   counter=$((counter +1))
fi

# Check the hosted zone has been cleared.        
if [[ -n "$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
   --output text)" ]]
then
   echo 'ERROR: testing delete_record DELETE record found in the hosted zone.'
   counter=$((counter +1))
fi 

# Clear the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null 

echo 'delete_record tests completed.'

###########################################
## TEST 7: check_hosted_zone_has_record
###########################################

# Insert a www.maxmin.it (18.203.73.111) record in the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null
__test_create_record 'www.maxmin.it' '18.203.73.111' > /dev/null

# Wrong hosted zone name.
if 'false' != "$(check_hosted_zone_has_record 'www' 'xxxxxx.it')"
then
  echo 'ERROR: testing check_hosted_zone_has_record www xxxxxx.it'
  counter=$((counter +1))
fi

# Empty record sub-domain.
if 'false' != "$(check_hosted_zone_has_record '' 'maxmin.it' )"
then
  echo 'ERROR: testing check_hosted_zone_has_record <empty string> maxmin.it'
  counter=$((counter +1))
fi

# Non existent record sub-domain.
if 'false' != "$(check_hosted_zone_has_record 'xxx' 'maxmin.it' )"
then
  echo 'ERROR: testing check_hosted_zone_has_record xxx maxmin.it'
  counter=$((counter +1))
fi

# Enter a valid search.
if test 'true' != "$(check_hosted_zone_has_record 'www' 'maxmin.it')"
then
   echo 'ERROR: testing check_hosted_zone_has_record www maxmin.it'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null

# Create an alias record.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null
__test_create_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Enter a valid search.
if test 'true' != "$(check_hosted_zone_has_record 'www' 'maxmin.it')"
then
   echo 'ERROR: testing check_hosted_zone_has_record www maxmin.it'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

echo 'check_hosted_zone_has_record tests completed.'

###########################################
## TEST 8: get_record_value
###########################################

# Insert a www.maxmin.it (18.203.73.111) record in the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null
__test_create_record 'www.maxmin.it' '18.203.73.111' > /dev/null

# Get the record value successfully.
ip8b="$(get_record_value 'www' 'maxmin.it')"

if [[ "${ip8b}" != '18.203.73.111' ]]
then
   echo 'ERROR: testing get_record_value serching a record, no record was found.'
   counter=$((counter +1))
fi  

# Search the record with a wrong sub-domain name, empty string is expected.
ip8c="$(get_record_value 'xxx' 'maxmin.it')"

if [[ -n "${ip8c}" ]]
then
   echo 'ERROR: testing get_record_value serching a record with wrong sub-domain name.'
   counter=$((counter +1))
fi  

# Search the record with a wrong hosted zone name, empty string is expected.
ip8d="$(get_record_value 'www' 'xxxxxx.it')"

if [[ -n "${ip8d}" ]]
then
   echo 'ERROR: testing get_record_value serching a record with wrong hosted zone name.'
   counter=$((counter +1))
fi  

# Clear the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111'> /dev/null 

echo 'get_record_value tests completed.'

###########################################
## TEST 9: __create_delete_alias_record
###########################################

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Send a wrong action name, error return code expected.
set +e
__create_delete_alias_record 'UPDATE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null
exit_code=$?
set -e 

if test $exit_code -eq 0
then
   echo 'ERROR: testing __create_delete_alias_record with wrong action name.'
   counter=$((counter +1))
fi

# Non existent hosted zone name, empty request id expected.
request_id9a="$(__create_delete_alias_record 'CREATE' 'www' 'xxxxxx.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"

if test -n "${request_id9a}"
then
   echo 'ERROR: testing __create_delete_alias_record non existent hosted zone name.'
   counter=$((counter +1))
fi

# Insert www.maxmin.it record successfully, valid request id expected.
request_id9b="$(__create_delete_alias_record 'CREATE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"
status9b="$(aws route53 get-change --id "${request_id9b}" --query ChangeInfo.Status --output text)"

if [[ "${status9b}" != 'INSYNC' && "${status9b}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_alias_record creating a record.'
   counter=$((counter +1))
fi

# Check the alias record target DNS name value.
value9b="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.DNSName" \
   --output text)"
   
if [[ "${value9b}" != '1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing __create_delete_alias_record retriving alias record target DNS name.'
   counter=$((counter +1))
fi   

# Check the alias record target hosted zone ID.
value9c="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.HostedZoneId" \
   --output text)"
   
if [[ "${value9c}" != 'Z32O12XQLNTSW2' ]]
then
   echo 'ERROR: testing __create_delete_alias_record retriving alias record target hosted zone.'
   counter=$((counter +1))
fi        

## Insert twice the same record, empty request id expected.
request_id9c="$(__create_delete_alias_record 'CREATE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"

if test -n "${request_id9c}"
then
   echo 'ERROR: testing __create_delete_alias_record creating twice a record.'
   counter=$((counter +1))
fi

# Delete www.maxmin.it successfully, valid request id expected.
request_id9d="$(__create_delete_alias_record 'DELETE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"
status9d="$(aws route53 get-change --id "${request_id9d}" --query ChangeInfo.Status --output text)"

if [[ "${status9d}" != 'INSYNC' && "${status9d}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_alias_record DELETE deleting a record.'
   counter=$((counter +1))
fi

## Delete twice the same record, empty request id expected.
request_id9e="$(__create_delete_alias_record 'DELETE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"

if test -n "${request_id9e}"
then
   echo 'ERROR: testing __create_delete_alias_record DELETE deleting twice the same record.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

echo '__create_delete_alias_record tests completed.'

###########################################
## TEST 10: get_record_request_status
###########################################

# Insert a www.maxmin.it (18.203.73.111) record in the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null
request_id10a="$(__test_create_record 'www.maxmin.it' '18.203.73.111')"

# Check the request.
status10a="$(get_record_request_status "${request_id10a}")"

if [[ 'PENDING' != "${status10a}" && 'INSYNC' != "${status10a}" ]]
then
   echo 'ERROR: testing get_record_request_status with valid request ID.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__test_delete_record 'www.maxmin.it' '18.203.73.111' > /dev/null

# Insert www.maxmin.it alias record .
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null
request_id10b="$(__test_create_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"

# Check the request.
status10b="$(get_record_request_status "${request_id10b}")"

if [[ 'PENDING' != "${status10b}" && 'INSYNC' != "${status10b}" ]]
then
   echo 'ERROR: testing get_record_request_status with valid alias request ID.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Check a not existing request, an empty string is expected.
status10c="$(get_record_request_status 'xxx')"

if test -n "${status10c}"
then
   echo 'ERROR: testing get_record_request_status with not existing request id.'
   counter=$((counter +1))
fi

echo 'get_record_request_status tests completed.'

###########################################
## TEST 11: get_alias_record_dns_name_value
###########################################

# Insert www.maxmin.it alias record.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null
__test_create_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Check with valid sub-domain name and valid hosted zone name.
dns_name_value11a="$(get_alias_record_dns_name_value 'www' 'maxmin.it')"

if [[ "${dns_name_value11a}" != '1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing get_alias_record_dns_name_value with valid alias record values.'
   counter=$((counter +1))
fi 

# Check with invalid sub-domain name.
dns_name_value11b="$(get_alias_record_dns_name_value 'xxx' 'maxmin.it')"

if [[ -n "${dns_name_value11b}" ]]
then
   echo 'ERROR: testing get_alias_record_dns_name_value with invalid sub-domain name.'
   counter=$((counter +1))
fi 

# Check with invalid hosted zone name.
dns_name_value11c="$(get_alias_record_dns_name_value 'www' 'xxxxx.it')"

if [[ -n "${dns_name_value11c}" ]]
then
   echo 'ERROR: testing get_alias_record_dns_name_value with invalid hosted zone name.'
   counter=$((counter +1))
fi 

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

echo 'get_alias_record_dns_name_value tests completed.'

###############################################
## TEST 12: get_alias_record_hosted_zone_value
###############################################

# Insert www.maxmin.it alias record .
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null
__test_create_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Check with valid sub-domain name and valid hosted zone name.
hosted_zone_name_value11a="$(get_alias_record_hosted_zone_value 'www' 'maxmin.it')"

if [[ "${hosted_zone_name_value11a}" != 'Z32O12XQLNTSW2' ]]
then
   echo 'ERROR: testing get_alias_record_hosted_zone_value with valid alias record values.'
   counter=$((counter +1))
fi 

# Check with invalid sub-domain name.
hosted_zone_name_value11b="$(get_alias_record_hosted_zone_value 'xxx' 'maxmin.it')"

if [[ -n "${hosted_zone_name_value11b}" ]]
then
   echo 'ERROR: testing get_alias_record_hosted_zone_value with invalid sub-domain name.'
   counter=$((counter +1))
fi 

# Check with invalid hosted zone name.
hosted_zone_name_value11c="$(get_alias_record_hosted_zone_value 'www' 'xxxxx.it')"

if [[ -n "${hosted_zone_name_value11c}" ]]
then
   echo 'ERROR: testing get_alias_record_hosted_zone_value with invalid hosted zone name.'
   counter=$((counter +1))
fi 

# Insert www.maxmin.it alias record .
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

echo 'get_alias_record_hosted_zone_value tests completed.'

################################################
## TEST 13: __create_type_A_record_change_batch
################################################

# Create a JSON request for a new type A record.
request_body13="$(__create_type_A_record_change_batch 'webphp1.maxmin.it' '34.242.102.242' 'CREATE' 'admin website')"

## First validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${request_body13}"
then
    # Get the comment element.
    comment="$(echo "${request_body13}" | jq -r '.Comment')"
    
    if [[ 'admin website' != "${comment}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong comment element."
       counter=$((counter +1))
    fi
    
    # Get the action element.
    action="$(echo "${request_body13}" | jq -r '.Changes[].Action')"
    
    if [[ 'CREATE' != "${action}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong action element."
       counter=$((counter +1))
    fi
    
    # Get the name element.
    name="$(echo "${request_body13}" | jq -r '.Changes[].ResourceRecordSet.Name')"
    
    if [[ 'webphp1.maxmin.it' != "${name}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong name element."
       counter=$((counter +1))
    fi
    
    # Get the type element.
    type="$(echo "${request_body13}" | jq -r '.Changes[].ResourceRecordSet.Type')"
    
    if [[ 'A' != "${type}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong type element."
       counter=$((counter +1))
    fi
    
    # Get the ip element.
    ip="$(echo "${request_body13}" | jq -r '.Changes[].ResourceRecordSet.ResourceRecords[].Value')"
    
    if [[ '34.242.102.242' != "${ip}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong ip element."
       counter=$((counter +1))
    fi
else
    echo "Failed to parse JSON __create_type_A_record_change_batch request batch"
    counter=$((counter +1))
fi

echo '__create_type_A_record_change_batch tests completed.'

################################################
## TEST 14: __create_alias_record_change_batch
################################################

request_body14="$(__create_alias_record_change_batch 'alias.maxmin.it' \
    '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' 'CREATE' 'load balancer record')"

## First validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${request_body14}"
then
    # Get the comment element.
    comment="$(echo "${request_body14}" | jq -r '.Comment')"
    
    if [[ 'load balancer record' != "${comment}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong comment element."
       counter=$((counter +1))
    fi
    
    # Get the action element.
    action="$(echo "${request_body14}" | jq -r '.Changes[].Action')"
    
    if [[ 'CREATE' != "${action}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong action element."
       counter=$((counter +1))
    fi
    
    # Get the name element.
    name="$(echo "${request_body14}" | jq -r '.Changes[].ResourceRecordSet.Name')"
    
    if [[ 'alias.maxmin.it' != "${name}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong name element."
       counter=$((counter +1))
    fi
    
    # Get the type element.
    type="$(echo "${request_body14}" | jq -r '.Changes[].ResourceRecordSet.Type')"
    
    if [[ 'A' != "${type}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong type element."
       counter=$((counter +1))
    fi
    
    # Get the hosted zone id element.
    hosted_zone_id="$(echo "${request_body14}" | jq -r '.Changes[].ResourceRecordSet.AliasTarget.HostedZoneId')"
    
    if [[ 'Z32O12XQLNTSW2' != "${hosted_zone_id}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong hosted_zone_id element."
    fi
    
    # Get the dns name element.
    dns_name="$(echo "${request_body14}" | jq -r '.Changes[].ResourceRecordSet.AliasTarget.DNSName')"
    
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

############################################
## TEST 15: __submit_change_batch
############################################

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Get a body for a request.
request_body15a="$(__create_alias_record_change_batch 'www.maxmin.it' \
    '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' 'CREATE' 'load balancer record')"
    
request_id15a="$(__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body15a}")"

status15a="$(aws route53 get-change --id "${request_id15a}" --query ChangeInfo.Status --output text)"

if [[ "${status15a}" != 'INSYNC' && "${status15a}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

echo '__submit_change_batch tests completed.'

###########################################
## TEST 16: create_alias_record
###########################################

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Insert www.maxmin.it record successfully, valid request id expected.
request_id16b="$(create_alias_record 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"
status16b="$(aws route53 get-change --id "${request_id16b}" --query ChangeInfo.Status --output text)"

# Check the status of the request.
if [[ "${status16b}" != 'INSYNC' && "${status16b}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_alias_record creating a record.'
   counter=$((counter +1))
fi

# Check the alias record target domain name value.
value16b="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.DNSName" \
   --output text)"

# Check that a trailing '.' dot has been appended to the target domain name   
if [[ "${value16b}" != '1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing create_alias_record retriving alias record target DNS name.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Insert the same record with a trailing '.' dot appended to the target domain name, verify that 
# the DNS record was created with a trailing '.' dot.
request_id16c="$(create_alias_record 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"
status16c="$(aws route53 get-change --id "${request_id16c}" --query ChangeInfo.Status --output text)"

if [[ "${status16c}" != 'INSYNC' && "${status16c}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_alias_record creating a record.'
   counter=$((counter +1))
fi

# Check the alias record target domain name value.
value16d="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.DNSName" \
   --output text)"

# Check that a trailing '.' dot has been appended to the target domain name   
if [[ "${value16d}" != '1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing create_alias_record retriving alias record target DNS name.'
   counter=$((counter +1))
fi   

# Check the alias record target hosted zone ID.
value16e="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.HostedZoneId" \
   --output text)"
   
if [[ "${value16e}" != 'Z32O12XQLNTSW2' ]]
then
   echo 'ERROR: testing create_alias_record retriving alias record target hosted zone.'
   counter=$((counter +1))
fi 

# Clear the hosted zone.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

echo 'create_alias_record tests completed.'


#############################################
## TEST 17: delete_alias_record
#############################################

# Insert www.maxmin.it alias record.
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null
__test_create_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Delete www.maxmin.it record passing a wrong target DNS name, an error is expected.
set +e
delete_alias_record 'www' 'maxmin.it' 'xxxxxx.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null 2>&1
exit_code=$?
set -e

if test $exit_code -eq 0
then
   echo 'ERROR: testing delete_alias_record with wrong target domain name.'
   counter=$((counter +1))
fi

# Delete www.maxmin.it record passing a wrong target hosted zone ID, an error is expected.
set +e
delete_alias_record 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'xxxxxx' > /dev/null 2>&1
exit_code=$?
set -e

if test $exit_code -eq 0
then
   echo 'ERROR: testing delete_alias_record with wrong target domain name.'
   counter=$((counter +1))
fi

# Delete www.maxmin.it record successfully.
request_id17b="$(delete_alias_record 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"
status17b="$(aws route53 get-change --id "${request_id17b}" --query ChangeInfo.Status --output text)"

if [[ "${status17b}" != 'INSYNC' && "${status17b}" != 'PENDING' ]]
then
   echo 'ERROR: testing delete_alias_record deleting a record.'
   counter=$((counter +1))
fi

# Clear the hosted zone.   
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

echo 'delete_alias_record tests completed.'

#############################################
## TEST 18: create_loadbalancer_alias_record
#############################################

# Clear the hosted zone.   
__test_delete_alias_record 'www.maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Insert www.maxmin.it record successfully, valid request id expected.
request_id18b="$(create_loadbalancer_alias_record 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"
status18b="$(aws route53 get-change --id "${request_id18b}" --query ChangeInfo.Status --output text)"

if [[ "${status18b}" != 'INSYNC' && "${status18b}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_loadbalancer_alias_record creating a record.'
   counter=$((counter +1))
fi

# Check the alias record target DNS name value.
value18b="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.DNSName" \
   --output text)"
   
# Check that the target DNS name has the 'dualstack' prefix appended and a '.' suffix appendend.
if [[ "${value18b}" != 'dualstack.1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing create_loadbalancer_alias_record retriving alias record target DNS name.'
   counter=$((counter +1))
fi   

# Check the alias record target hosted zone ID.
value18c="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.HostedZoneId" \
   --output text)"
   
if [[ "${value18c}" != 'Z32O12XQLNTSW2' ]]
then
   echo 'ERROR: testing create_loadbalancer_alias_record retriving alias record target hosted zone.'
   counter=$((counter +1))
fi 

# Clear the hosted zone: the 'dualstack' prefix has to be appendend to the target domain name.
__test_delete_alias_record 'www.maxmin.it' 'dualstack.1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Insert the same record with a target dns name with a trailing '.' dot.
# Verify that the 'dualstack' prefix is present and the trailing '.' dot is present.
request_id18c="$(create_loadbalancer_alias_record 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2')"
status18c="$(aws route53 get-change --id "${request_id18c}" --query ChangeInfo.Status --output text)"

if [[ "${status18c}" != 'INSYNC' && "${status18c}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_loadbalancer_alias_record creating a record.'
   counter=$((counter +1))
fi

# Check the alias record target DNS name value.
value18c="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.DNSName" \
   --output text)"
   
# Check that the target DNS name has the 'dualstack' prefix appended and a '.' suffix appendend.
if [[ "${value18c}" != 'dualstack.1203266565.eu-west-1.elb.amazonaws.com.' ]]
then
   echo 'ERROR: testing create_loadbalancer_alias_record retriving alias record target DNS name.'
   counter=$((counter +1))
fi   

# Check the alias record target hosted zone ID.
value18d="$(aws route53 list-resource-record-sets \
   --hosted-zone-id "${HOSTED_ZONE_ID}" \
   --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].AliasTarget.HostedZoneId" \
   --output text)"
   
if [[ "${value18d}" != 'Z32O12XQLNTSW2' ]]
then
   echo 'ERROR: testing create_loadbalancer_alias_record retriving alias record target hosted zone.'
   counter=$((counter +1))
fi 

# Clear the hosted zone: the 'dualstack' prefix has to be appendend to the target domain name.         
__test_delete_alias_record 'www.maxmin.it' 'dualstack.1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

echo 'create_loadbalancer_alias_record tests completed.' 

if [[ "${counter}" -gt 0 ]]
then
   echo "Error: running route53.sh tests, ${counter} errors found."
else
   echo 'route53.sh script test successful.'
fi

