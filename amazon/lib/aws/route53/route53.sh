#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
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
# For public hosted zones, Route 53 automatically creates a default SOA record 
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
# records are not yet available on all Route 53 DNS servers. 
# When the NS and SOA records are available, the status of the zone changes to 
# INSYNC .
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm    -- the hosted zone name, this is the name you have registered with your DNS 
#                       registrar.
# +caller_reference  -- Any unique string that identifies the request and that 
#                       allows failed CreateHostedZone requests to be retried 
#                       without the risk of executing the operation twice.
# +comment           -- Any comments that you want to include about the hosted 
#                       zone.
# Returns:      
#  the hosted zone identifier.  
#===============================================================================
function create_hosted_zone()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local hosted_zone_nm="${1}"
   local caller_reference="${2}"
   local comment="${3}"
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
# +hosted_zone_nm -- the hosted zone name, this is the name you have registered 
#                    with your DNS registrar (eg: maxmin.it).
# Returns:      
#  None
#===============================================================================
function delete_hosted_zone()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local hosted_zone_nm="${1}"
   local hosted_zone_id=''
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
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
# +hosted_zone_nm -- the hosted zone name, this is the name you have registered 
#                    with your DNS registrar (eg. maxmin.it).
# Returns:      
#  true/false value.
#===============================================================================
function check_hosted_zone_exists() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local hosted_zone_nm="${1}"
   local exists='false'
   local hosted_zone_id=''
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      exists='true'
   fi
   
   echo "${exists}"
   
   return 0
}

#===============================================================================
# Returns a hosted zone's name servers.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm -- the hosted zone name, this is the name you have registered 
#                    with your DNS registrar.
# Returns:      
#  a string representing the hosted zone name servers:
#  ex: ns-128.awsdns-16.com ns-1930.awsdns-49.co.uk ns-752.awsdns-30.net 
#      ns-1095.awsdns-08.org,
#  or blanc if not found.
#===============================================================================
function get_hosted_zone_name_servers() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local hosted_zone_nm="${1}"
   local name_servers=''
   local hosted_zone_id=''
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      name_servers="$(aws route53 get-hosted-zone \
          --id "${hosted_zone_id}" \
          --query DelegationSet.NameServers[*] \
          --output text)"
   fi   
   
   echo "${name_servers}"
   
   return 0
}

#===============================================================================
# Check if a hosted zone contains a record.
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm  -- the record name, eg. www
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with your DNS registrar (eg: maxmin.it).

# Returns:      
#  true/false value.  
#===============================================================================
function check_hosted_zone_has_record() 
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local domain="${sub_domain_nm}"."${hosted_zone_nm}"
   local has_record='false'
   local record=''
   local hosted_zone_id=''
      
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      record="$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${hosted_zone_id}" \
          --query "ResourceRecordSets[?contains(Name,'${domain}')].Name" \
          --output text)"

      if [[ -n "${record}" ]]
      then
         has_record='true'
      fi                
   fi 
     
   echo "${has_record}"
   
   return 0
}

#===============================================================================
# Returns where a record routes the traffic to, eg: an IP address, a DNS 
# address.
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm  -- the record sub-domain name, eg. www
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with your DNS registrar (eg: maxmin.it).
# Returns:      
#  the record's route value, or blanc if not found.  
#===============================================================================
function get_record_value() 
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local domain="${sub_domain_nm}"."${hosted_zone_nm}"
   local hosted_zone_id=''
   local value=''

   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      value="$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${hosted_zone_id}" \
          --query "ResourceRecordSets[?contains(Name,'${domain}')].ResourceRecords[*].Value" \
          --output text)"
   fi 
                    
   echo "${value}"
   
   return 0
}

#===============================================================================
# Returns the DNS address targeted by an alias record.
# An Alias record is used to route traffic to selected AWS resources, such as 
# CloudFront distributions and Amazon S3 buckets, AWS load balancer, or to route 
# traffic from one record in a hosted zone to another record.
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm  -- the record sub-domain name, eg. www
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with your DNS registrar (eg: maxmin.it).
# Returns:      
#  the DNS address where the alias record routes the traffic ti, or blanc if not 
#  found.  
#===============================================================================
function get_alias_record_dns_name_value() 
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local domain="${sub_domain_nm}"."${hosted_zone_nm}"
   local hosted_zone_id=''
   local value=''
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      value="$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${hosted_zone_id}" \
          --query "ResourceRecordSets[?contains(Name,'${domain}')].AliasTarget.DNSName" \
          --output text)"
   fi 
                    
   echo "${value}"
   
   return 0
}

#===============================================================================
# Returns the targeted hosted zone ID of an alias record.
# An Alias record is used to route traffic to selected AWS resources, such as 
# CloudFront distributions and Amazon S3 buckets, AWS load balancer, or to route 
# traffic from one record in a hosted zone to another record.
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm  -- the record sub-domain name, eg. www
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with your DNS registrar (eg: maxmin.it).
# Returns:      
#  the targeted hosted zone ID.  
#===============================================================================
function get_alias_record_hosted_zone_value() 
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local domain="${sub_domain_nm}"."${hosted_zone_nm}"
   local hosted_zone_id=''
   local value=''
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      value="$(aws route53 list-resource-record-sets \
          --hosted-zone-id "${hosted_zone_id}" \
          --query "ResourceRecordSets[?contains(Name,'${domain}')].AliasTarget.HostedZoneId" \
          --output text)"
   fi 
   
   echo "${value}"
 
   return 0
}

#===============================================================================
# Adds a type A record to a hosted zone.
# Type A-records are the DNS server equivalent of the hosts file, a simple 
# domain name to IP-address mapping. 
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm  -- the alias sub-domain name, eg. www.
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with the DNS registrar.
# +ip_address     -- the IP address associated to the domain name.
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted.  
#===============================================================================
function create_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local ip_address="${3}"
   local request_id=''
   
   request_id="$(__create_delete_record \
       'CREATE' \
       "${sub_domain_nm}" \
       "${hosted_zone_nm}" \
       "${ip_address}")"
       
   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Deletes a type A record from a hosted zone.
# If the subdomain is not passed, the domain is considered a top level domain.
# Changes to a hosted zoned generally propagate to all Route 53 name servers 
# within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm      -- the alias sub-domain name, eg. www
# +hosted_zone_nm     -- the hosted zone name, this is the name you have 
#                        registered with your DNS registrar.
# +ip_address         -- the IP address associated to the domain name.
# Returns:      
#  the ID of the request.  
#===============================================================================
function delete_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local ip_address="${3}"
   local request_id=''
   
   request_id="$(__create_delete_record \
       'DELETE' \
       "${sub_domain_nm}" \
       "${hosted_zone_nm}" \
       "${ip_address}")"

   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Adds/remove a type A record to/from a hosted zone.
# Type A-records are the DNS server equivalent of the hosts file, a simple 
# domain name to IP-address mapping. 
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +action         -- either CREATE or DELETE.
# +sub_domain_nm  -- the alias sub-domain name, eg. www.
# +hosted_zone_nm -- the hosted zone name, this is the name you have 
#                    registered with the DNS registrar.
# +ip_address     -- the IP address associated to the domain name.
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted.  
#===============================================================================
function __create_delete_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local action="${1}"
   local sub_domain_nm="${2}"
   local hosted_zone_nm="${3}"
   local ip_address="${4}"
   local domain="${sub_domain_nm}"."${hosted_zone_nm}"
   local hosted_zone_id=''
   local request_id=''
   local has_record='false'
   
   if [[ 'CREATE' != "${action}" && 'DELETE' != "${action}" ]]
   then
      echo 'ERROR: action can only be CREATE and DELETE.'
      return 1
   fi
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      has_record="$(check_hosted_zone_has_record "${sub_domain_nm}" "${hosted_zone_nm}")"
      
      if [[ 'CREATE' == "${action}" && 'false' == "${has_record}" ||
            'DELETE' == "${action}" && 'true' == "${has_record}" ]]
      then
          request_body="$(__create_type_A_record_change_batch "${domain}" \
              "${ip_address}" \
              "${action}" \
              "Type A Record for ${ip_address}")"
              
          request_id="$(__submit_change_batch "${hosted_zone_id}" "${request_body}")"          
      fi  
   fi

   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Creates a load balancer record.
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm         -- the load balancer sub-domain name, eg. www.
# +hosted_zone_nm        -- the hosted zone name, this is the name you have 
#                           registered with the DNS registrar.
# +target_domain_nm      -- the targeted load balancer domain name.
# +target_hosted_zone_id -- the targeted load balancer hosted zone identifier. 
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted.  
#===============================================================================
function create_loadbalancer_alias_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local target_domain_nm="${3}"
   local target_hosted_zone_id="${4}"
   local modified_target_domain_nm="${target_domain_nm}"
   local request_id=''
   
   if [[ "${target_domain_nm}" != 'dualstack'* ]]
   then
      modified_target_domain_nm="dualstack.${target_domain_nm}"
   fi
   
   request_id="$(create_alias_record \
       "${sub_domain_nm}" \
       "${hosted_zone_nm}" \
       "${modified_target_domain_nm}" \
       "${target_hosted_zone_id}")"
       
   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Adds an alias record to a hosted zone.
# An Alias record is used to route traffic to selected AWS resources, such as 
# CloudFront distributions and Amazon S3 buckets, AWS load balancer, or to route 
# traffic from one record in a hosted zone to another record.
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm         -- the alias sub-domain name, eg. www.
# +hosted_zone_nm        -- the hosted zone name, this is the name you have 
#                           registered with the DNS registrar.
# +target_domain_nm      -- the domain name referred by the alias.
# +target_hosted_zone_id -- the hosted zone identifier to which belong the 
#                           target domain name. 
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted.  
#===============================================================================
function create_alias_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local target_domain_nm="${3}"
   local target_hosted_zone_id="${4}"
   local request_id=''
   
   request_id="$(__create_delete_alias_record \
       'CREATE' \
       "${sub_domain_nm}" \
       "${hosted_zone_nm}" \
       "${target_domain_nm}" \
       "${target_hosted_zone_id}")"
       
   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Deletes a load balancer record.
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm         -- the load balancer sub-domain name, eg. www.
# +hosted_zone_nm        -- the hosted zone name, this is the name you have 
#                           registered with the DNS registrar.
# +target_domain_nm      -- the targeted load balancer domain name.
# +target_hosted_zone_id -- the targeted load balancer hosted zone identifier. 
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted. 
#===============================================================================
function delete_loadbalancer_alias_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local target_domain_nm="${3}"
   local target_hosted_zone_id="${4}"
   local modified_target_domain_nm="${target_domain_nm}"
   local request_id=''
     
   if [[ "${target_domain_nm}" != 'dualstack'* ]]
   then
      modified_target_domain_nm="dualstack.${target_domain_nm}"
   fi
     
   request_id="$(delete_alias_record \
       "${sub_domain_nm}" \
       "${hosted_zone_nm}" \
       "${modified_target_domain_nm}" \
       "${target_hosted_zone_id}")"
         
   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Deletes an alias record from a hosted zone.
# An Alias record is used to route traffic to selected AWS resources, such as 
# CloudFront distributions and Amazon S3 buckets, AWS load balancer, or to route 
# traffic from one record in a hosted zone to another record.
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm         -- the alias sub-domain name, eg. www.
# +hosted_zone_nm        -- the hosted zone name, this is the name you have 
#                           registered with the DNS registrar.
# +target_domain_nm      -- the domain name referred by the alias.
# +target_hosted_zone_id -- the hosted zone identifier to which belong the 
#                           target domain name. 
# Returns:      
#  the ID of the request.  
#===============================================================================
function delete_alias_record()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local sub_domain_nm="${1}"
   local hosted_zone_nm="${2}"
   local target_domain_nm="${3}"
   local target_hosted_zone_id="${4}"
   local request_id=''
   
   request_id="$(__create_delete_alias_record \
       'DELETE' \
       "${sub_domain_nm}" \
       "${hosted_zone_nm}" \
       "${target_domain_nm}" \
       "${target_hosted_zone_id}")"

   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Adds/removes an alias record to/from a hosted zone.
# An Alias record is used to route traffic to selected AWS resources, such as 
# CloudFront distributions and Amazon S3 buckets, AWS load balancer, or to route 
# traffic from one record in a hosted zone to another record.
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +action                -- either CREATE or DELETE.
# +sub_domain_nm         -- the alias sub-domain name, eg. www.
# +hosted_zone_nm        -- the hosted zone name, this is the name you have 
#                           registered with the DNS registrar.
# +target_domain_nm      -- the domain name referred by the alias.
# +target_hosted_zone_id -- the hosted zone identifier to which belong the 
#                           target domain name. 
# Returns:      
#  the ID of the request of a blanc string if the request is not submitted. #===============================================================================
function __create_delete_alias_record()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local action="${1}"
   local sub_domain_nm="${2}"
   local hosted_zone_nm="${3}"
   local target_domain_nm="${4}"  
   local target_hosted_zone_id="${5}"
   local domain="${sub_domain_nm}"."${hosted_zone_nm}"
   local hosted_zone_id=''
   local request_id=''
   local has_record='false'
   
   if [[ 'CREATE' != "${action}" && 'DELETE' != "${action}" ]]
   then
      echo 'ERROR: action can only be CREATE and DELETE.'
      return 1
   fi
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   if [[ -n "${hosted_zone_id}" ]]
   then
      has_record="$(check_hosted_zone_has_record "${sub_domain_nm}" "${hosted_zone_nm}")"
      
      if [[ 'CREATE' == "${action}" && 'false' == "${has_record}" ||
            'DELETE' == "${action}" && 'true' == "${has_record}" ]]
      then
         request_body="$(__create_alias_record_change_batch "${domain}" \
             "${target_domain_nm}" \
             "${target_hosted_zone_id}" \
             "${action}" \
             "Alias record for ${sub_domain_nm}.${hosted_zone_nm}")"

         request_id="$(__submit_change_batch "${hosted_zone_id}" "${request_body}")"           
      fi  
   fi

   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Returns the current status of a request to add/delete a record in the hosted
# zone.
# The status is one of the following values:
# PENDING indicates that the changes in this request have not propagated to 
# all Amazon Route 53 DNS servers. This is the initial status of all change 
# batch requests.
# INSYNC indicates that the changes have propagated to all Route 53 DNS servers.
#
# Globals:
#  None
# Arguments:
# +request_id -- the ID of the request.
# Returns:      
#  the status of the request or a blanc string if the request is not found.  
#===============================================================================
function get_record_request_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local request_id="${1}"
   local status=''

   status="$(aws route53 get-change --id "${request_id}" \
       --query ChangeInfo.Status --output text 2> /dev/null)"
   
   echo "${status}"
   
   return 0
}

#===============================================================================
# Creates the change batch request to create, delete or update a type A record.
# A records are the DNS server equivalent of the hosts file, a simple domain 
# name to IP-address mapping. 
#
# Globals:
#  None
# Arguments:
# +domain_nm  -- the DNS domain name.
# +ip_address -- the IP address associated to the domain.
# +action     -- CREATE | DELETE | UPSERT
# +comment    -- comment about the changes in this change batch request.
# Returns:      
#  a JSON string representing a change batch request for a type A record.  
#=============================================================================== 
function __create_type_A_record_change_batch()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local domain_nm="${1}"
   local ip_address="${2}"
   local action="${3}"
   local comment="${4}"
   local template
   
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
   
   change_batch="$(printf '%b\n' "${template}" \
       | sed -e "s/SEDdomain_nameSED/${domain_nm}/g" \
             -e "s/SEDip_addressSED/${ip_address}/g" \
             -e "s/SEDcommentSED/${comment}/g" \
             -e "s/SEDactionSED/${action}/g")" 
   
   echo "${change_batch}"
   
   return 0
}

#===============================================================================
# Creates the change batch request body to create, delete or update an alias 
# record type.  
#
# Globals:
#  None
# Arguments:
# +domain_nm             -- the DNS domain name.
# +target_domain_nm      -- the DNS name referred by the alias.
# +target_hosted_zone_id -- the identifier of the hosted zone of the DNS domain name.
# +action                -- CREATE | DELETE | UPSERT
# +comment               -- comment about the changes in this change batch request.
# Returns:      
#  the change batch containing the changes to apply to a hosted zone.  
#=============================================================================== 
function __create_alias_record_change_batch()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local domain_nm="${1}"
   local target_domain_nm="${2}"
   local target_hosted_zone_id="${3}"
   local action="${4}"
   local comment="${5}"
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
  
   change_batch="$(printf '%b\n' "${template}" \
                    | sed -e "s/SEDdomain_nmSED/${domain_nm}/g" \
                          -e "s/SEDtarget_domain_nmSED/${target_domain_nm}/g" \
                          -e "s/SEDtarget_hosted_zone_idSED/${target_hosted_zone_id}/g" \
                          -e "s/SEDcommentSED/${comment}/g" \
                          -e "s/SEDactionSED/${action}/g")" 
   
   echo "${change_batch}"
   
   return 0
}

#===============================================================================
# Submit the change batch request.
# Changes generally propagate to all Route 53 name servers within 60 seconds.  
#
# Globals:
#  None
# Arguments:
# +hosted_zone_id -- the hosted zone identifier.
# +request_body   -- the request details.
# Returns:      
#  the change batch request identifier or a blanc string if the request is not
#  submitted.  
#=============================================================================== 
function __submit_change_batch()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local hosted_zone_id="${1}"
   local request_body="${2}"
   local request_id=''

   ## Submit the changes in the batch to the hosted zone.
   request_id="$(aws route53 change-resource-record-sets \
       --hosted-zone-id "${hosted_zone_id}" \
       --change-batch "${request_body}" \
       --query ChangeInfo.Id \
       --output text)"
               
   echo "${request_id}"
   
   return 0                              
}

#===============================================================================
# Gets a hosted zone identifier.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm -- the hosted zone name, this is the name you have registered  
#                    with the DNS registrar. 
# Returns:      
#  the hosted zone identifier or an empty string if not found. 
#===============================================================================
function __get_hosted_zone_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local domain_nm="${1}"
   local hosted_zone_id

   # The domain name must be followed by a dot.
   hosted_zone_id="$(aws route53 list-hosted-zones \
       --query "HostedZones[?Name=='${domain_nm}.'].{Id: Id}" \
       --output text)"        
             
   echo "${hosted_zone_id}"          
   
   return 0
}






