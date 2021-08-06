#!/usr/bin/bash 

set -e
# command-substitution-inherit_errexit.sh
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: route53.sh
#   DESCRIPTION: The script contains functions that use AWS client to make 
#                calls to Amazon Elastic Compute Cloud (Amazon EC2).
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#
# A public hosted zone defines how you want to route traffic on the internet 
# for a domain, such as example.com, and its subdomains (apex.example.com, 
# acme.example.com). 
# You can't create a hosted zone for a top-level domain (TLD) such as .com.
# For public hosted zones, route 53 automatically creates a default SOA record 
# and four NS records for the zone. 
# If you want to use the same name servers for multiple public hosted zones, 
# you can optionally associate a reusable delegation set with the hosted zone.
#
# SOA: Start of authority, used to designate the primary name server and 
# administrator responsible for a zone. Each zone hosted on a DNS server must 
# have an SOA (start of authority) record. You can modify the record as needed 
# (for example, you can change the serial number to an arbitrary number to 
# support date-based versioning).
#
# NS: Name server record, which delegates a DNS zone to an authoritative server.
#
# You can delete a hosted zone only if there are no records other than the 
# default SOA and NS records. If your hosted zone contains other records, 
# you must delete them before you can delete your hosted zone.
#
# If you want to keep your domain registration but you want to stop routing 
# internet traffic to your website or web application, we recommend that you 
# delete records in the hosted zone instead of deleting the hosted zone.
#
# If you delete a hosted zone, you can't undelete it. You must create a new 
# hosted zone and update the name servers for your domain registration, which 
# can require up to 48 hours to take effect. In addition, if you delete a hosted 
# zone, someone could hijack the domain and route traffic to their own 
# resources using your domain name.
#
# If you want to avoid the monthly charge for the hosted zone, you can transfer 
# DNS service for the domain to a free DNS service. When you transfer DNS 
# service, you have to update the name servers for the domain registration.
#
#
# Both Route53 and ELB are used to distribute the network traffic. 
# These AWS services appear similar but there are minor differences between them.

# ELB distributes traffic among Multiple Availability Zone but not to multiple Regions. 
# Route53 can distribute traffic among multiple Regions. 
# In short, ELBs are intended to load balance across EC2 instances in a single region whereas DNS 
# load-balancing (Route53) is intended to help balance traffic across regions.
#
#===============================================================================

#===============================================================================
# Creates a new public or private hosted zone. 
# When you submit a CreateHostedZone request, the initial status of the hosted 
# zone is PENDING . For public hosted zones, this means that the NS and SOA 
# records are not yet available on all route 53 DNS servers. 
# When the NS and SOA records are available, the status of the zone changes to 
# INSYNC .
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm   -- the hosted zone name, this is the name you have 
#                      registered with your DNS registrar (eg: maxmin.it).
#                      It is a fully qualified domain name (RFC 1034), must end 
#                      with a dot, eg: maxmin.it.
# +caller_reference -- any unique string that identifies the request and that 
#                      allows failed CreateHostedZone requests to be retried 
#                      without the risk of executing the operation twice.
# +comment          -- any comments that you want to include about the hosted 
#                      zone.
# Returns:      
#  the hosted zone identifier, prints the result in the stdout.  
#===============================================================================
function create_hosted_zone()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r hosted_zone_nm="${1}"
   declare -r caller_reference="${2}"
   declare -r comment="${3}"
   local hosted_zone_id=''

   hosted_zone_id="$(aws route53 create-hosted-zone \
       --name "${hosted_zone_nm}" \
       --caller-reference "${caller_reference}" \
       --hosted-zone-config Comment="${comment}" \
       --query 'HostedZone.Id' \
       --output text)"
   
   echo "${hosted_zone_id}"
   
   return 0
}

#===============================================================================
# Deletes a hosted zone.
# You can delete a hosted zone only if it contains only the default SOA record 
# and NS resource record sets. If the hosted zone contains other resource record 
# sets, you must delete them before you can delete the hosted zone. 
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with your DNS registrar (eg: maxmin.it).
#                    It is a fully qualified domain name (RFC 1034), must end 
#                    with a dot, eg: maxmin.it.
# Returns:      
#  None
#===============================================================================
function delete_hosted_zone()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r hosted_zone_nm="${1}"
   local hosted_zone_id=''
   
   __get_hosted_zone_id "${hosted_zone_nm}"
   hosted_zone_id="${__RESULT}"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      aws route53 delete-hosted-zone --id "${hosted_zone_id}"
   else
      echo 'WARN: hosted zone not found.'
   fi
   
   return 0
}

#===============================================================================
# Checks if a hosted zone exits.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with your DNS registrar (eg: maxmin.it).
#                    It is a fully qualified domain name (RFC 1034), must end 
#                    with a dot, eg: maxmin.it.
# Returns:      
#  true/false value, returns the value in the __RESULT variable.
#===============================================================================
function check_hosted_zone_exists() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r hosted_zone_nm="${1}"
   local exists='false'
   local hosted_zone_id=''
   
   __get_hosted_zone_id "${hosted_zone_nm}"
   hosted_zone_id="${__RESULT}"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      exists='true'
   fi
   
   eval "__RESULT='${exists}'"
   
   return 0
}

#===============================================================================
# Returns a hosted zone's name servers.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with your DNS registrar (eg: maxmin.it).
#                    It is a fully qualified domain name (RFC 1034), must end 
#                    with a dot, eg: maxmin.it.
# Returns:      
#  a string representing the hosted zone name servers:
#  ex: ns-128.awsdns-16.com ns-1930.awsdns-49.co.uk ns-752.awsdns-30.net 
#      ns-1095.awsdns-08.org,
#  or blanc if not found.
# Returns:      
#  the list of the hosted zone's name servers, returns the value in the __RESULT 
#  variable.
#===============================================================================
function get_hosted_zone_name_servers() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r hosted_zone_nm="${1}"
   local name_servers=''
   local hosted_zone_id=''
   
   __get_hosted_zone_id "${hosted_zone_nm}"
   hosted_zone_id="${__RESULT}"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      name_servers="$(aws route53 get-hosted-zone \
          --id "${hosted_zone_id}" \
          --query DelegationSet.NameServers[*] \
          --output text)"
   fi   
   
   eval "__RESULT='${name_servers}'"
   
   return 0
}

#===============================================================================
# Check if a hosted zone contains a record. To check if the hosted zone contains
# an AWS alias type record, the record_type parameter passed must be 'aws-type'.
# Amazon Route 53 alias records provide a Route 53–specific extension to DNS 
# functionality. AWS alias are inserted in the hosted zone as type A records.
#
# Globals:
#  None
# Arguments:
# +record_type -- the record type, eg: A, NS, or aws-alias.
# +domain_nm   -- the fully qualified domain name, eg: 'www.maxmin.'
# Returns:      
#  true/false value, returns the value in the __RESULT variable.
#===============================================================================
function check_hosted_zone_has_record() 
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r record_type="${1}"
   declare -r domain_nm="${2}"
   local has_record='false'
   local record=''
      
   get_record_value "${record_type}" "${domain_nm}"
   record="${__RESULT}" 
      
   if [[ -n "${record}" ]]
   then
      has_record='true'
   fi                 
    
   eval "__RESULT='${has_record}'"
   
   return 0
}

#===============================================================================
# Returns the value of a record in a hosted zone. To get the value of an AWS 
# alias type record, the record_type parameter passed must be 'aws-type'.
# Amazon Route 53 alias records provide a Route 53–specific extension to DNS 
# functionality. AWS alias are inserted in the hosted zone as type A records.
#
# Globals:
#  None
# Arguments:
# +record_type -- the record type, eg: A, NS, or aws-alias.
# +domain_nm   -- the fully qualified domain name, eg: 'www.maxmin.'
# Returns:      
#  the record value, returns the value in the __RESULT variable.  
#===============================================================================
function get_record_value() 
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r record_type="${1}"
   declare -r domain_nm="${2}"
   local record=''
   local hosted_zone_nm=''
   local hosted_zone_id=''

   hosted_zone_nm=$(echo "${domain_nm}" | awk -F . '{printf("%s.%s.", $2, $3)}')
   __get_hosted_zone_id "${hosted_zone_nm}"
   hosted_zone_id="${__RESULT}"

   if [[ -z "${hosted_zone_id}" ]]  
   then 
      # Hosted zone not found.
      eval "__RESULT=''"
      return 0
   fi 
      
   if [[ 'aws-alias' == "${record_type}" ]]
   then
      record="$(aws route53 list-resource-record-sets \
           --hosted-zone-id "${hosted_zone_id}" \
           --query "ResourceRecordSets[? Type == 'A' && Name == '${domain_nm}' ].AliasTarget.DNSName" \
           --output text)"
    
   else
      record="$(aws route53 list-resource-record-sets \
           --hosted-zone-id "${hosted_zone_id}" \
           --query "ResourceRecordSets[? Type == '${record_type}' && Name == '${domain_nm}' ].ResourceRecords[*].Value" \
           --output text)"
   fi                  
           
   eval "__RESULT='${record}'"
   
   return 0
}

#===============================================================================
# Creates the change batch request to create, delete or update a type A or NS
# record.
# A records are the DNS server equivalent of the hosts file, a simple domain 
# name to IP-address mapping. 
#
# Globals:
#  None
# Arguments:
# +domain_nm    -- the fully qualified domain name, eg: 'www.maxmin.'
# +record_value -- the value associated to the domain, eg: an IP address in case
#                  of a type A record, a domain name in case of a NS type 
#                  record.
# +action       -- CREATE | DELETE
# +comment      -- comment about the changes in this change batch request.
# Returns:      
#  a JSON string representing a change batch request for a type A record, 
#  returns the value in the __RESULT variable. 
#=============================================================================== 
function __create_record_change_batch()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r action="${1}"
   declare -r record_type="${2}"
   declare -r domain_nm="${3}"
   declare -r record_value="${4}"
   declare -r comment="${5}"
   local template=''
   local change_batch=''
   
   template=$(cat <<-'EOF'
        {
           "Comment":"SEDcommentSED",
           "Changes":
              [
                 {
                    "Action":"SEDactionSED",
                    "ResourceRecordSet":
                       {
                          "Name":"SEDdomain_nameSED",
                          "Type":"SEDrecord_typeSED",
                          "TTL":120,
                          "ResourceRecords":
                             [
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
   
   change_batch="$(printf '%b\n' "${template}" \
       | sed -e "s/SEDdomain_nameSED/${domain_nm}/g" \
             -e "s/SEDrecord_valueSED/${record_value}/g" \
             -e "s/SEDrecord_typeSED/${record_type}/g" \
             -e "s/SEDcommentSED/${comment}/g" \
             -e "s/SEDactionSED/${action}/g")" 
   
   eval "__RESULT='${change_batch}'"
   
   return 0
}

#===============================================================================
# Creates the change batch request body to create, delete or update an alias 
# record type.  
#
# Globals:
#  None
# Arguments:
# +domain_nm             -- the fully qualified domain name, eg: 'www.maxmin.'
# +target_domain_nm      -- the DNS name referred by the alias.
# +target_hosted_zone_id -- the identifier of the hosted zone of the DNS domain 
#                           name.
# +action                -- CREATE | DELETE
# +comment               -- comment about the changes in this change batch 
#                           request.
# Returns:      
#  the change batch containing the changes to apply to a hosted zone, returns 
#  the value in the __RESULT variable.   
#=============================================================================== 
function __create_alias_record_change_batch()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r action="${1}"
   declare -r domain_nm="${2}"
   declare -r record_value="${3}"
   declare -r target_hosted_zone_id="${4}"
   declare -r comment="${5}"
   local template=''
   local change_batch=''
   
   template=$(cat <<-'EOF' 
        {
           "Comment":"SEDcommentSED",
           "Changes":
              [
                 {
                    "Action":"SEDactionSED",
                    "ResourceRecordSet":
                       {
                          "Name":"SEDdomain_nmSED",
                          "Type":"A",
                          "AliasTarget":
                             {
                                "HostedZoneId":"SEDtarget_hosted_zone_idSED",
                                "DNSName":"SEDrecord_valueSED",
                                "EvaluateTargetHealth":false
                             }
                       }
                 }
             ]
        }       
	EOF
   )
  
   change_batch="$(printf '%b\n' "${template}" \
       | sed -e "s/SEDdomain_nmSED/${domain_nm}/g" \
             -e "s/SEDrecord_valueSED/${record_value}/g" \
             -e "s/SEDtarget_hosted_zone_idSED/${target_hosted_zone_id}/g" \
             -e "s/SEDcommentSED/${comment}/g" \
             -e "s/SEDactionSED/${action}/g")" 
   
   eval "__RESULT='${change_batch}'"
   
   return 0
}

#===============================================================================
# Adds a record in a hosted zone if the record is not present.  
# Removes a record in a hosted zone if the record is present.  
# The record type may be A, NS or aws-alias.
# Type A-records are the DNS server equivalent of the hosts file, a simple 
# domain name to IP-address mapping. 
# Amazon Route 53 alias records provide a Route 53–specific extension to DNS 
# functionality. AWS alias are inserted in the hosted zone as type A records.
# Changes generally propagate to all route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +action                -- either CREATE or DELETE.
# +record_type           -- the type of the record, either A, NS or aws-alias.
# +domain_nm             -- the fully qualified domain name, eg: 'www.maxmin.'
# +record_value          -- the value of the record type, eg: an IP address, a  
#                           DNS domain.
# +target_hosted_zone_id -- optional, if the record is a aws-alias, the targeted
#                           hosted zone identifier.
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted, 
#  returns the value in the __RESULT variable.
#===============================================================================
function __create_delete_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r action="${1}"
   declare -r record_type="${2}"
   declare -r domain_nm="${3}"
   declare -r record_value="${4}"
   local target_hosted_zone_id=''
      
   if [[ $# -eq 5 ]]
   then
      target_hosted_zone_id="${5}"
   fi   

   local request_body=''
   local hosted_zone_nm=''
   local hosted_zone_id=''
   local request_id=''
   local has_record='false'
   
   if [[ 'CREATE' != "${action}" && 'DELETE' != "${action}" ]]
   then
      echo 'ERROR: action can only be CREATE and DELETE.'
      return 128
   fi
   
   if [[ 'A' != "${record_type}" && 'NS' != "${record_type}" && 'aws-alias' != "${record_type}" ]]
   then
      echo 'ERROR: record type can only be A, NS, aws-alias.'
      return 128
   fi   
   
   hosted_zone_nm=$(echo "${domain_nm}" | awk -F . '{printf("%s.%s.", $2, $3)}')
   __get_hosted_zone_id "${hosted_zone_nm}"
   hosted_zone_id="${__RESULT}"

   if [[ -z "${hosted_zone_id}" ]]  
   then 
      # Hosted zone not found.
      eval "__RESULT=''"
      return 0
   fi 
    
   check_hosted_zone_has_record "${record_type}" "${domain_nm}"
   has_record="${__RESULT}"
 
   if [[ 'CREATE' == "${action}" && 'false' == "${has_record}" ||
         'DELETE' == "${action}" && 'true' == "${has_record}" ]]
   then
      if [[ 'aws-alias' == "${record_type}" ]]
      then       
         # aws-alias record type.
         __create_alias_record_change_batch \
             "${action}" "${domain_nm}" "${record_value}" "${target_hosted_zone_id}" "AWS alias record for ${domain_nm}"
         request_body="${__RESULT}"         
      else      
         # A or NS record type.
         __create_record_change_batch \
             "${action}" "${record_type}" "${domain_nm}" "${record_value}" "Record for ${record_value}"
         request_body="${__RESULT}"         
      fi

      __submit_change_batch "${hosted_zone_id}" "${request_body}" 
      request_id="${__RESULT}"
   fi   
   
   eval "__RESULT='${request_id}'"
   
   return 0
}

#===============================================================================
# Returns the current status of a request to add/delete a record in the hosted
# zone.
# The status is one of the following values:
# PENDING indicates that the changes in this request have not propagated to 
# all Amazon route 53 DNS servers. This is the initial status of all change 
# batch requests.
# INSYNC indicates that the changes have propagated to all route 53 DNS servers.
#
# Globals:
#  None
# Arguments:
# +request_id -- the ID of the request.
# Returns:      
#  the status of the request or a blanc string if the request is not found, 
#  returns the value in the __RESULT variable. 
#===============================================================================
function get_record_request_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r request_id="${1}"
   local status=''

   set +e
   status="$(aws route53 get-change --id "${request_id}" \
       --query ChangeInfo.Status --output text 2>/dev/null )"
   set -e
   
   eval "__RESULT='${status}'"
   
   return 0
}

#===============================================================================
# Submit the change batch request.
# Changes generally propagate to all route 53 name servers within 60 seconds.  
#
# Globals:
#  None
# Arguments:
# +hosted_zone_id -- the hosted zone identifier.
# +request_body   -- the request details.
# Returns:      
#  the change batch request identifier or a blanc string if there is an error, 
#  returns the value in the __RESULT variable.  
#=============================================================================== 
function __submit_change_batch()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r hosted_zone_id="${1}"
   declare -r request_body="${2}"
   local request_id=''

   set +e
   request_id="$(aws route53 change-resource-record-sets \
       --hosted-zone-id "${hosted_zone_id}" \
       --change-batch "${request_body}" \
       --query ChangeInfo.Id \
       --output text 2>/dev/null)"
   set -e
         
   eval "__RESULT='${request_id}'"
   
   return 0                              
}

#===============================================================================
# Gets a hosted zone identifier.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with your DNS registrar (eg: maxmin.it).
#                    It is a fully qualified domain name (RFC 1034), must end 
#                    with a dot, eg: maxmin.it.
# Returns:      
#  the hosted zone identifier or an empty string if not found, returns the value 
#  in the __RESULT variable.  
#===============================================================================
function __get_hosted_zone_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r hosted_zone_nm="${1}"
   local hosted_zone_id=''

   hosted_zone_id="$(aws route53 list-hosted-zones \
       --query "HostedZones[? Name=='${hosted_zone_nm}'].{Id: Id}" \
       --output text)"        
             
   eval "__RESULT='${hosted_zone_id}'"          
   
   return 0
}

#===============================================================================
# Check if a hosted zone contains a load balancer record. 
# Amazon Route 53 alias records provide a Route 53–specific extension to DNS 
# functionality. AWS alias are inserted in the hosted zone as type A records.
#
# Globals:
#  None
# Arguments:
# +domain_nm -- the fully qualified domain name, eg: 'www.maxmin.'
# Returns:      
#  true/false value, returns the value in the __RESULT variable.  
#===============================================================================
function check_hosted_zone_has_loadbalancer_record() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r domain_nm="${1}"
   local has_record='false'
   local record=''
      
   get_record_value 'aws-alias' "${domain_nm}"   
   record="${__RESULT}"
   
   if [[ -n "${record}" ]]
   then
      has_record='true'
   fi                 
     
   eval "__RESULT='${has_record}'"   
   
   return 0
}

#===============================================================================
# Creates a load balancer record if the record is not already created. 
# A load balancer record is an aws-alias record type.
# Amazon Route 53 alias records provide a Route 53–specific extension to DNS 
# functionality.
# Changes generally propagate to all route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +domain_nm             -- the fully qualified domain name, eg: 'www.maxmin.'
# +record_value          -- the targeted load balancer domain name.
# +target_hosted_zone_id -- the targeted load balancer hosted zone identifier.  
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted,
#  returns the value in the __RESULT variable.   
#===============================================================================
function create_loadbalancer_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r domain_nm="${1}"
   declare -r record_value="${2}"
   declare -r target_hosted_zone_id="${3}"
   local request_id=''    

   __create_delete_record \
       'CREATE' 'aws-alias' "${domain_nm}" "${record_value}" "${target_hosted_zone_id}"
   request_id="${__RESULT}"
   
   eval "__RESULT='${request_id}'" 
   
   return 0
}

#===============================================================================
# Deletes a load balancer record if the record is present in the hosted zone. 
# A load balancer record is an aws-alias record type.
# Amazon Route 53 alias records provide a Route 53–specific extension to DNS 
# functionality.
# Changes generally propagate to all route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +domain_nm             -- the fully qualified domain name, eg: 'www.maxmin.'
# +record_value          -- the targeted load balancer domain name.
# +target_hosted_zone_id -- the targeted load balancer hosted zone identifier. 
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted, 
#  returns the value in the __RESULT variable.  
#===============================================================================
function delete_loadbalancer_record()
{
if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r domain_nm="${1}"
   declare -r record_value="${2}"
   declare -r target_hosted_zone_id="${3}"
   local request_id=''

   __create_delete_record \
       'DELETE' 'aws-alias' "${domain_nm}" "${record_value}" "${target_hosted_zone_id}"
   request_id="${__RESULT}"    

   eval "__RESULT='${request_id}'"
   
   return 0
}

#===============================================================================
# Returns the targeted hosted zone ID of an alias record.
# Amazon Route 53 alias records provide a Route 53–specific extension to DNS 
# functionality.
# An Alias record is used to route traffic to selected AWS resources, such as 
# CloudFront distributions and Amazon S3 buckets, AWS load balancer, or to route 
# traffic from one record in a hosted zone to another record.
#
# Globals:
#  None
# Arguments:
# +domain_nm -- the fully qualified domain name, eg: 'www.maxmin.'
# Returns:      
#  the targeted hosted zone ID, returns the value in the __RESULT variable.  
#===============================================================================
function get_loadbalancer_record_hosted_zone_value() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r domain_nm="${1}"
   local hosted_zone_nm=''
   local hosted_zone_id=''
   local target_hosted_zone_id=''
      
   hosted_zone_nm=$(echo "${domain_nm}" | awk -F . '{printf("%s.%s.", $2, $3)}')  
   
   __get_hosted_zone_id "${hosted_zone_nm}"
   hosted_zone_id="${__RESULT}"
     
   if [[ -n "${hosted_zone_id}" ]]
   then
      target_hosted_zone_id="$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${hosted_zone_id}" \
          --query "ResourceRecordSets[? contains(Name,'${domain_nm}')].AliasTarget.HostedZoneId" \
          --output text)"
   fi 
   
   eval "__RESULT='${target_hosted_zone_id}'"
 
   return 0
}

#===============================================================================
# Returns the DNS domain address targeted by a load balancer record.
# A load balancer record is an aws-alias record type.
# Amazon Route 53 alias records provide a Route 53–specific extension to DNS 
# functionality.
#
# Globals:
#  None
# Arguments:
# +domain_nm -- the fully qualified domain name, eg: 'www.maxmin.'
# Returns:      
#  the DNS address where the alias record routes the traffic to, or blanc if not 
#  found, returns the value in the __RESULT variable. 
#===============================================================================
function get_loadbalancer_record_dns_name_value() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r domain_nm="${1}"
   local record_value=''
   
   get_record_value 'aws-alias' "${domain_nm}"
   record_value="${__RESULT}"
   
   eval "__RESULT='${record_value}'"
   
   return 0
}

#===============================================================================
# Adds a record in a hosted zone if the record is not present. 
# The record type may be A, NS.
# Changes generally propagate to all route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +record_type  -- the type of the record, either A, NS or aws-alias.
# +domain_nm    -- the fully qualified domain name, eg: 'www.maxmin.'
# +record_value -- the value of the record type, eg: an IP address, a  
#                  DNS domain.
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted, 
#  returns the value in the __RESULT variable.   
#===============================================================================
function create_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r record_type="${1}"
   declare -r domain_nm="${2}"
   declare -r record_value="${3}"
   local request_id=''
    
   if [[ 'A' != "${record_type}" && 'NS' != "${record_type}" ]]
   then
      echo 'ERROR: record type can only be A, NS.'
      return 128
   fi     

   __create_delete_record 'CREATE' "${record_type}" "${domain_nm}" "${record_value}" 
   request_id="${__RESULT}"
   
   eval "__RESULT='${request_id}'"
   
   return 0
}

#===============================================================================
# Removes a record in a hosted zone if the record is present.  
# The record type may be A, NS.
# Changes generally propagate to all route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +record_type  -- the type of the record, either A, NS or aws-alias.
# +domain_nm    -- the fully qualified domain name, eg: 'www.maxmin.'
# +record_value -- the value of the record type, eg: an IP address, a  
#                  DNS domain.
# Returns:      
#  the ID of the request, returns the value in the __RESULT variable.     
#===============================================================================
function delete_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r record_type="${1}"
   declare -r domain_nm="${2}"
   declare -r record_value="${3}"
   local request_id=''
    
   if [[ 'A' != "${record_type}" && 'NS' != "${record_type}" ]]
   then
      echo 'ERROR: record type can only be A, NS.'
      return 128
   fi     

   __create_delete_record 'DELETE' "${record_type}" "${domain_nm}" "${record_value}"
   request_id="${__RESULT}"
   
   eval "__RESULT='${request_id}'"
   
   return 0
}
