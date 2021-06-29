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
counter=0

echo 'Testing route53.sh ...'

set +e

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

# Send a wrong action name, error return code expected.
__create_delete_record 'UPDATE' 'www' 'maxmin.it' '18.203.73.111' >> /dev/null
exit_code=$?

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

if [[ "${status4d}" != 'INSYNC' && "${status4d}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_record DELETE deleting a record.'
   counter=$((counter +1))
fi

request_id4e="$(__create_delete_record 'DELETE' 'www' 'maxmin.it' '18.203.73.111')"

## Delete twice the same record, empty request id expected.
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
   echo 'ERROR: clearing hosted zone.'
   exit 1
fi 

echo '__create_delete_record tests completed.'

###########################################
## TEST 5: create_record
###########################################

# Create a record successfully, valid request id expected.
request_id5a="$(create_record 'www' 'maxmin.it' '18.203.73.111')"
status5a="$(aws route53 get-change --id "${request_id5a}" --query ChangeInfo.Status --output text)"

if [[ "${status5a}" != 'INSYNC' && "${status5a}" != 'PENDING' ]]
then
   echo 'ERROR: testing create_record creating a record, wrong request status.'
   counter=$((counter +1))
fi

# Check the record.
ip5a="$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].ResourceRecords[*].Value" \
          --output text)"
      
if [[ "${ip5a}" != '18.203.73.111' ]]
then
   echo 'ERROR: testing create_record wrong value found.'
   counter=$((counter +1))
fi     

echo 'create_record tests completed.'

###########################################
## TEST 6: delete_record
###########################################

# Insert a record in the hosted zone.
create_record 'www' 'maxmin.it' '18.203.73.111' > /dev/null

# Check the record has been created.    
if [[ -z "$(aws route53 list-resource-record-sets \
           --hosted-zone-id "${HOSTED_ZONE_ID}" \
           --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
           --output text)" ]]
then
   echo 'ERROR: creating record.'
   exit 1
fi 

# Delete a record successfully, valid request id expected.
request_id6a="$(delete_record 'www' 'maxmin.it' '18.203.73.111')"
status6a="$(aws route53 get-change --id "${request_id6a}" --query ChangeInfo.Status --output text)"

if [[ "${status6a}" != 'INSYNC' && "${status6a}" != 'PENDING' ]]
then
   echo 'ERROR: testing delete_delete_record deleting a record.'
   counter=$((counter +1))
fi

# Check if the record has been deleted, empty string is expected.
ip6b="$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].ResourceRecords[*].Value" \
          --output text)"
          
if [[ -n "${ip6b}" ]]
then
   echo 'ERROR: testing create_record deleting a record, the record wasn''t deleted.'
   counter=$((counter +1))
fi 

echo 'delete_record tests completed.'

###########################################
## TEST 7: check_hosted_zone_has_record
###########################################

# Insert a record in the hosted zone.
create_record 'www' 'maxmin.it' '18.203.73.111' > /dev/null

# Check the record has been created.          
if [[ -z "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: creating record.'
   exit 1
fi 

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

# Record found in hosted zone.
if test 'true' != "$(check_hosted_zone_has_record 'www' 'maxmin.it')"
then
   echo 'ERROR: testing check_hosted_zone_has_record www maxmin.it'
   counter=$((counter +1))
fi

# Clear the hosted zone.
delete_record 'www' 'maxmin.it' '18.203.73.111' > /dev/null
          
# Check the hosted zone has been cleared.               
if [[ -n "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: clearing hosted zone.'
   exit 1
fi 

echo 'check_hosted_zone_has_record tests completed.'

###########################################
## TEST 8: get_record_value
###########################################

# Insert a record in the hosted zone.
create_record 'www' 'maxmin.it' '18.203.73.111' > /dev/null

# Check the record has been created.          
if [[ -z "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: testing create_record deleting a record, the record wasn''t deleted.'
   counter=$((counter +1))
fi 

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
delete_record 'www' 'maxmin.it' '18.203.73.111' > /dev/null
          
# Check the hosted zone has been cleared.               
if [[ -n "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: clearing hosted zone.'
   exit 1
fi 

echo 'get_record_value tests completed.'

###########################################
## TEST 9: __create_delete_alias_record
###########################################

# Send a wrong action name, error return code expected.
__create_delete_alias_record 'UPDATE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' > /dev/null
exit_code=$?

if test $exit_code -eq 0
then
   echo 'ERROR: testing __create_delete_alias_record with wrong action name.'
   counter=$((counter +1))
fi

# Non existent hosted zone name, empty request id expected.
request_id9a="$(__create_delete_alias_record 'CREATE' 'www' 'xxxxxx.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"

if test -n "${request_id9a}"
then
   echo 'ERROR: testing __create_delete_alias_record non existent hosted zone name.'
   counter=$((counter +1))
fi

# Insert www.maxmin.it record successfully, valid request id expected.
request_id9b="$(__create_delete_alias_record 'CREATE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"
status9b="$(aws route53 get-change --id "${request_id9b}" --query ChangeInfo.Status --output text)"

if [[ "${status9b}" != 'INSYNC' && "${status9b}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_alias_record creating a record.'
   counter=$((counter +1))
fi

## Insert twice the same record, empty request id expected.
request_id9c="$(__create_delete_alias_record 'CREATE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"

if test -n "${request_id9c}"
then
   echo 'ERROR: testing __create_delete_alias_record creating twice a record.'
   counter=$((counter +1))
fi

# Delete www.maxmin.it successfully, valid request id expected.
request_id9d="$(__create_delete_alias_record 'DELETE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"
status9d="$(aws route53 get-change --id "${request_id9d}" --query ChangeInfo.Status --output text)"

if [[ "${status9d}" != 'INSYNC' && "${status9d}" != 'PENDING' ]]
then
   echo 'ERROR: testing __create_delete_alias_record DELETE deleting a record.'
   counter=$((counter +1))
fi

## Delete twice the same record, empty request id expected.
request_id9e="$(__create_delete_alias_record 'DELETE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"

if test -n "${request_id9e}"
then
   echo 'ERROR: testing __create_delete_alias_record DELETE deleting twice the same record.'
   counter=$((counter +1))
fi

# Check the hosted zone has been cleared.               
if [[ -n "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: clearing hosted zone.'
   exit 1
fi 

echo '__create_delete_alias_record tests completed.'

###########################################
## TEST 10: get_record_request_status
###########################################

# Insert a record in the hosted zone.
request_id="$(create_record 'www' 'maxmin.it' '18.203.73.111')"

# Check the record has been created.          
if [[ -z "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: creating record.'
   exit 1
fi 

# Check an existing request.
status10a="$(get_record_request_status "${request_id}")"

if [[ 'PENDING' != "${status10a}" && 'INSYNC' != "${status10a}" ]]
then
   echo 'ERROR: testing get_record_request_status <request id>'
   counter=$((counter +1))
fi

# Check a not existing request.
status10b="$(get_record_request_status 'xxx')"

if test -n "${status10b}"
then
   echo 'ERROR: testing get_record_request_status with not existing request id.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
delete_record 'www' 'maxmin.it' '18.203.73.111' > /dev/null
          
# Check the hosted zone has been cleared.               
if [[ -n "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: clearing hosted zone.'
   exit 1
fi 

echo 'get_record_request_status tests completed.'

###########################################
## TEST 11: get_alias_record_dns_name_value
###########################################

# Insert www.maxmin.it alias record .
__create_delete_alias_record 'CREATE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Check the record is inserted.              
if [[ -z "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: creating record.'
   exit 1
fi 

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
__create_delete_alias_record 'DELETE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' > /dev/null

# Check the hosted zone has been cleared.               
if [[ -n "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: clearing hosted zone.'
   exit 1
fi 

echo 'get_alias_record_dns_name_value tests completed.'

###############################################
## TEST 12: get_alias_record_hosted_zone_value
###############################################

# Insert www.maxmin.it alias record .
__create_delete_alias_record 'CREATE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Check the record is inserted.              
if [[ -z "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: creating record.'
   exit 1
fi 

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

# Clear the hosted zone.
__create_delete_alias_record 'DELETE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com.' 'Z32O12XQLNTSW2' > /dev/null

# Check the hosted zone has been cleared.               
if [[ -n "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: clearing hosted zone.'
   exit 1
fi 

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

############################################
## TEST 14: __create_alias_record_change_batch
############################################

request_body14="$(__create_alias_record_change_batch 'alias.maxmin.it' \
    '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' 'CREATE' 'load balancer record')"

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
    
    if [[ '1203266565.eu-west-1.elb.amazonaws.com' != "${dns_name}" ]]
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

# Get a body for a request.
request_body15a="$(__create_alias_record_change_batch 'www.maxmin.it' \
    '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' 'CREATE' 'load balancer record')"
    
request_id15a="$(__submit_change_batch "${HOSTED_ZONE_ID}" "${request_body15a}")"

status15a="$(aws route53 get-change --id "${request_id15a}" --query ChangeInfo.Status --output text)"

if [[ "${status15a}" != 'INSYNC' && "${status15a}" != 'PENDING' ]]
then
   echo 'ERROR: testing __submit_change_batch.'
   counter=$((counter +1))
fi

# Clear the hosted zone.
__create_delete_alias_record 'DELETE' 'www' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' > /dev/null

# Check the hosted zone has been cleared.               
if [[ -n "$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${HOSTED_ZONE_ID}" \
          --query "ResourceRecordSets[?contains(Name,'www.maxmin.it')].Name" \
          --output text)" ]]
then
   echo 'ERROR: clearing hosted zone.'
   exit 1
fi 

echo '__submit_change_batch tests completed.' 

if [[ "${counter}" -gt 0 ]]
then
   echo 'Error: running route53.sh tests, ${counter} errors found.'
else
   echo 'route53.sh tests successful'
fi


###########################################
## TEST: create_alias_record
###########################################

###########################################
## TEST: create_loadbalancer_alias_record
###########################################

###########################################
## TEST: delete_loadbalancer_alias_record
###########################################

###########################################
## TEST: delete_alias_record
###########################################

set -e

