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
## TEST: __get_hosted_zone_id
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

if test -n "$(__get_hosted_zone_id 'admin.maxmin.it')" 
then
  echo 'ERROR: testing __get_hosted_zone_id admin.maxmin.it'
  counter=$((counter +1))
fi

echo '__get_hosted_zone_id tests completed'

###########################################
## TEST: check_hosted_zone_exists
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

if 'false' != "$(check_hosted_zone_exists 'admin.maxmin.it')"
then
  echo 'ERROR: testing check_hosted_zone_exists admin.maxmin.it'
  counter=$((counter +1))
fi

if 'false' != "$(check_hosted_zone_exists 'it')"
then
  echo 'ERROR: testing check_hosted_zone_exists it'
  counter=$((counter +1))
fi

echo 'check_hosted_zone_exists tests completed'

###########################################
## TEST: get_hosted_zone_name_servers
###########################################

servers="$(get_hosted_zone_name_servers 'maxmin.it')"

if [[ "${servers}" != *"${NS1}"* || "${servers}" != *"${NS2}"* || \
      "${servers}" != *"${NS3}"* || "${servers}" != *"${NS4}"* ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers maxmin.it'
   counter=$((counter +1))
fi

servers="$(get_hosted_zone_name_servers '')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers <empty string>'
   counter=$((counter +1))
fi

servers="$(get_hosted_zone_name_servers 'admin.maxmin.it')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers admin.maxmin.it'
   counter=$((counter +1))
fi

servers="$(get_hosted_zone_name_servers 'it')"

if [[ -n "${servers}" ]]
then
   echo 'ERROR: testing get_hosted_zone_name_servers it'
   counter=$((counter +1))
fi

echo 'get_hosted_zone_name_servers tests completed'

###########################################
## TEST: __create_delete_record
###########################################

__create_delete_record 'UPDATE' 'www' 'maxmin.it' '18.203.73.111' >> /dev/null
exit_code=$?

if test $exit_code -eq 0
then
   echo 'ERROR: testing __create_delete_record with wrong action value.'
   counter=$((counter +1))
fi

if test -n "$(__create_delete_record 'CREATE' 'www' 'xxxxxx.it' '18.203.73.111')"
then
   echo 'ERROR: testing __create_delete_record CREATE www xxxxxx.it 18.203.73.111'
   counter=$((counter +1))
fi

if test -z "$(__create_delete_record 'CREATE' 'www' 'maxmin.it' '18.203.73.111')"
then
   echo 'ERROR: testing __create_delete_record CREATE www maxmin.it 18.203.73.111'
   counter=$((counter +1))
fi

## Insert twice the same record.
if test -n "$(__create_delete_record 'CREATE' 'www' 'maxmin.it' '18.203.73.111')"
then
   echo 'ERROR: testing twice __create_delete_record CREATE www maxmin.it 18.203.73.111'
   counter=$((counter +1))
fi

if test -z "$(__create_delete_record 'DELETE' 'www' 'maxmin.it' '18.203.73.111')"
then
   echo 'ERROR: testing __create_delete_record DELETE www maxmin.it 18.203.73.111'
   counter=$((counter +1))
fi

## Delete twice the same record.
if test -n "$(__create_delete_record 'DELETE' 'www' 'maxmin.it' '18.203.73.111')"
then
   echo 'ERROR: testing twice __create_delete_record DELETE www maxmin.it 18.203.73.111'
   counter=$((counter +1))
fi

echo '__create_delete_record tests completed'

###########################################
## TEST: create_record
###########################################

#
# Create a www.maxmin.it record and leave it there for the next tests.
#

if test -z "$(create_record 'www' 'maxmin.it' '18.203.73.111')"
then
   echo 'ERROR: testing __create_delete_record www maxmin.it 18.203.73.111'
   counter=$((counter +1))
fi

echo 'create_record tests completed'

###########################################
## TEST: check_hosted_zone_has_record
###########################################

if 'false' != "$(check_hosted_zone_has_record 'www' 'xxxxxx.it')"
then
  echo 'ERROR: testing check_hosted_zone_has_record www .it'
  counter=$((counter +1))
fi

if 'false' != "$(check_hosted_zone_has_record '' 'maxmin.it' )"
then
  echo 'ERROR: testing check_hosted_zone_has_record <empty string> maxmin.it'
  counter=$((counter +1))
fi

if 'false' != "$(check_hosted_zone_has_record 'xxx' 'maxmin.it' )"
then
  echo 'ERROR: testing check_hosted_zone_has_record xxx maxmin.it'
  counter=$((counter +1))
fi

if test 'true' != "$(check_hosted_zone_has_record 'www' 'maxmin.it')"
then
   echo 'ERROR: testing check_hosted_zone_has_record www maxmin.it'
   counter=$((counter +1))
fi

echo 'check_hosted_zone_has_record tests completed'

###########################################
## TEST: get_record_value
###########################################

if test -z "$(get_record_value 'www' 'maxmin.it')"
then
   echo 'ERROR: testing get_record_value www maxmin.it'
   counter=$((counter +1))
fi

if test -n "$(get_record_value 'xxx' 'maxmin.it')"
then
   echo 'ERROR: testing get_record_value xxx maxmin.it'
   counter=$((counter +1))
fi

if test -n "$(get_record_value 'www' 'xxxxxx.it')"
then
   echo 'ERROR: testing get_record_value www xxxxxx.it'
   counter=$((counter +1))
fi

echo 'get_record_value tests completed'

###########################################
## TEST: __create_delete_alias_record
###########################################

__create_delete_alias_record 'UPDATE' 'lbal' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' >> /dev/null
exit_code=$?

if test $exit_code -eq 0
then
   echo 'ERROR: testing __create_delete_alias_record with wrong action value.'
   counter=$((counter +1))
fi

if test -n "$(__create_delete_alias_record 'CREATE' 'lbal' 'xxxxx.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"
then
   echo 'ERROR: testing __create_delete_alias_record CREATE lbal xxxxxx.it 1203266565.eu-west-1.elb.amazonaws.com Z32O12XQLNTSW2'
   counter=$((counter +1))
fi

if test -z "$(__create_delete_alias_record 'CREATE' 'lbal' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"
then
   echo 'ERROR: testing __create_delete_alias_record CREATE www maxmin.it 1203266565.eu-west-1.elb.amazonaws.com Z32O12XQLNTSW2'
   counter=$((counter +1))
fi

## Insert twice the same record.
if test -n "$(__create_delete_alias_record 'CREATE' 'lbal' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"
then
   echo 'ERROR: testing twice __create_delete_alias_record CREATE www maxmin.it 1203266565.eu-west-1.elb.amazonaws.com Z32O12XQLNTSW2'
   counter=$((counter +1))
fi

if test -z "$(__create_delete_alias_record 'DELETE' 'lbal' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"
then
   echo 'ERROR: testing __create_delete_alias_record DELETE www maxmin.it 1203266565.eu-west-1.elb.amazonaws.com Z32O12XQLNTSW2'
   counter=$((counter +1))
fi

## Delete twice the same record.
if test -n "$(__create_delete_alias_record 'DELETE' 'lbal' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"
then
   echo 'ERROR: testing twice __create_delete_alias_record DELETE www maxmin.it 1203266565.eu-west-1.elb.amazonaws.com Z32O12XQLNTSW2'
   counter=$((counter +1))
fi

echo '__create_delete_alias_record tests completed'

###########################################
## TEST: create_alias_record
###########################################

#
# Create a lbal.maxmin.it alias record and leave it there for the next tests.
#

request_id="$(create_alias_record 'lbal' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"

if test -z "${request_id}"
then
   echo 'ERROR: testing create_alias_record www maxmin.it 1203266565.eu-west-1.elb.amazonaws.com Z32O12XQLNTSW2'
   counter=$((counter +1))
fi

echo 'create_alias_record tests completed'

###########################################
## TEST: get_record_request_status
###########################################

status="$(get_record_request_status "${request_id}")"

if [[ 'PENDING' != "${status}" && 'INSYNC' != "${status}" ]]
then
   echo 'ERROR: testing get_record_request_status <request id>'
   counter=$((counter +1))
fi

status="$(get_record_request_status 'abc')"

if test -n "${status}"
then
   echo 'ERROR: testing get_record_request_status with not existing request id.'
   counter=$((counter +1))
fi

echo 'get_record_request_status tests completed'

###########################################
## TEST: get_alias_record_dns_name_value
###########################################

if test -z "$(get_alias_record_dns_name_value 'lbal' 'maxmin.it')"
then
   echo 'ERROR: testing get_alias_record_dns_name_value lbal maxmin.it'
   counter=$((counter +1))
fi

if test -n "$(get_alias_record_dns_name_value 'xxx' 'maxmin.it')"
then
   echo 'ERROR: testing get_alias_record_dns_name_value xxx maxmin.it'
   counter=$((counter +1))
fi

if test -n "$(get_alias_record_dns_name_value 'lbal' 'xxxxxx.it')"
then
   echo 'ERROR: testing get_alias_record_dns_name_value lbal xxxxxx.it'
   counter=$((counter +1))
fi

echo 'get_alias_record_dns_name_value tests completed'

###########################################
## TEST: get_alias_record_hosted_zone_value
###########################################

if test -z "$(get_alias_record_hosted_zone_value 'lbal' 'maxmin.it')"
then
   echo 'ERROR: testing get_alias_record_hosted_zone_value lbal maxmin.it'
   counter=$((counter +1))
fi

if test -n "$(get_alias_record_hosted_zone_value 'xxx' 'maxmin.it')"
then
   echo 'ERROR: testing get_alias_record_hosted_zone_value xxx maxmin.it'
   counter=$((counter +1))
fi

if test -n "$(get_alias_record_hosted_zone_value 'lbal' 'xxxxxx.it')"
then
   echo 'ERROR: testing get_alias_record_hosted_zone_value lbal xxxxxx.it'
   counter=$((counter +1))
fi

echo 'get_alias_record_hosted_zone_value tests completed'

###########################################
## TEST: delete_record
###########################################

if test -z "$(delete_record 'www' 'maxmin.it' '18.203.73.111')"
then
   echo 'ERROR: testing delete_record www maxmin.it 18.203.73.111'
   counter=$((counter +1))
fi

echo 'delete_record tests completed'

###########################################
## TEST: delete_alias_record
###########################################

if test -z "$(delete_alias_record 'lbal' 'maxmin.it' '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2')"
then
   echo 'ERROR: testing delete_alias_record www maxmin.it 1203266565.eu-west-1.elb.amazonaws.com Z32O12XQLNTSW2'
   counter=$((counter +1))
fi

echo 'delete_alias_record tests completed'

############################################
## TEST: __create_type_A_record_change_batch
############################################

request="$(__create_type_A_record_change_batch 'webphp1.maxmin.it' '34.242.102.242' 'CREATE' 'admin website')"

## First validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${request}"
then
    
    comment="$(echo $request | jq -r '.Comment')"
    
    if [[ 'admin website' != "${comment}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong comment element."
       counter=$((counter +1))
    fi

    action="$(echo $request | jq -r '.Changes[].Action')"
    
    if [[ 'CREATE' != "${action}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong action element."
       counter=$((counter +1))
    fi
    
    name="$(echo $request | jq -r '.Changes[].ResourceRecordSet.Name')"
    
    if [[ 'webphp1.maxmin.it' != "${name}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong name element."
       counter=$((counter +1))
    fi
    
    type="$(echo $request | jq -r '.Changes[].ResourceRecordSet.Type')"
    
    if [[ 'A' != "${type}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong type element."
       counter=$((counter +1))
    fi
    
    ip="$(echo $request | jq -r '.Changes[].ResourceRecordSet.ResourceRecords[].Value')"
    
    if [[ '34.242.102.242' != "${ip}" ]]
    then
       echo "ERROR: testing __create_type_A_record_change_batch wrong ip element."
       counter=$((counter +1))
    fi
    
else
    echo "Failed to parse JSON __create_type_A_record_change_batch request batch"
    counter=$((counter +1))
fi

echo '__create_type_A_record_change_batch tests completed'

############################################
## TEST: __create_alias_record_change_batch
############################################

request="$(__create_alias_record_change_batch 'lbal.maxmin.it' \
    '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' 'CREATE' 'load balancer record')"

## First validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${request}"
then

    comment="$(echo $request | jq -r '.Comment')"
    
    if [[ 'load balancer record' != "${comment}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong comment element."
       counter=$((counter +1))
    fi
    
    action="$(echo $request | jq -r '.Changes[].Action')"
    
    if [[ 'CREATE' != "${action}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong action element."
       counter=$((counter +1))
    fi
    
    name="$(echo $request | jq -r '.Changes[].ResourceRecordSet.Name')"
    
    if [[ 'lbal.maxmin.it' != "${name}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong name element."
       counter=$((counter +1))
    fi
    
    type="$(echo $request | jq -r '.Changes[].ResourceRecordSet.Type')"
    
    if [[ 'A' != "${type}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong type element."
       counter=$((counter +1))
    fi
    
    hosted_zone_id="$(echo $request | jq -r '.Changes[].ResourceRecordSet.AliasTarget.HostedZoneId')"
    
    if [[ 'Z32O12XQLNTSW2' != "${hosted_zone_id}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong hosted_zone_id element."
    fi
    
    dns_name="$(echo $request | jq -r '.Changes[].ResourceRecordSet.AliasTarget.DNSName')"
    
    if [[ '1203266565.eu-west-1.elb.amazonaws.com' != "${dns_name}" ]]
    then
       echo "ERROR: testing __create_alias_record_change_batch wrong dns_name element."
       counter=$((counter +1))
    fi    
    
else
    echo "ERROR: Failed to parse JSON __create_alias_record_change_batch request batch"
    counter=$((counter +1))
fi

echo '__create_alias_record_change_batch tests completed'

############################################
## TEST: __submit_change_batch
############################################

request="$(__create_alias_record_change_batch 'lbal.maxmin.it' \
    '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' 'CREATE' 'load balancer record')"

if test -z "$(__submit_change_batch "${HOSTED_ZONE_ID}" "${request}")"
then
   echo 'ERROR: testing __submit_change_batch'
   counter=$((counter +1))
fi

request="$(__create_alias_record_change_batch 'lbal.maxmin.it' \
    '1203266565.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' 'DELETE' 'load balancer record')"
    
if test -z "$(__submit_change_batch "${HOSTED_ZONE_ID}" "${request}")"
then
   echo 'ERROR: testing __submit_change_batch'
   counter=$((counter +1))
fi  

echo '__submit_change_batch tests completed' 

if [[ "${counter}" -gt 0 ]]
then
   echo "route53.sh tests completed, found ${counter} errors."
   exit 1
else
   echo 'route53.sh tests successful'
fi

set -e

