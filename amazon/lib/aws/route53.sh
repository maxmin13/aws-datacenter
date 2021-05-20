#!/usr/bin/bash

set -o errexit
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
# When you register a domain with Route 53, we automatically make Route 53 the 
# DNS service for the domain. Route 53 creates a hosted zone that has the same 
# name as the domain, assigns four name servers to the hosted zone, and updates 
# the domain to use those name servers.
#
# A public hosted zone defines how you want to route traffic on the internet 
# for a domain, such as example.com, and its subdomains (apex.example.com, 
# acme.example.com). 
# You can't create a hosted zone for a top-level domain (TLD)  such as .com.
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
# If you delegated responsibility for a subdomain to a hosted zone and you want 
# to delete the child hosted zone, you must also update the parent hosted zone 
# by deleting the NS record that has the same name as the child hosted zone. 
# We recommend that you delete the NS record first, and wait for the duration 
# of the TTL on the NS record before you delete the child hosted zone. 
# This ensures that someone can't hijack the child hosted zone during the period 
# that DNS resolvers still have the name servers for the child hosted zone 
# cached.
#
# If you want to avoid the monthly charge for the hosted zone, you can transfer 
# DNS service for the domain to a free DNS service. When you transfer DNS 
# service, you have to update the name servers for the domain registration.
#===============================================================================

#===============================================================================
# Creates a new public hosted zone. 
# When you submit a CreateHostedZone request, the initial status of the hosted 
# zone is PENDING . For public hosted zones, this means that the NS and SOA 
# records are not yet available on all Route 53 DNS servers. 
# When the NS and SOA records are available, the status of the zone changes to 
# INSYNC .
#
# Globals:
#  None
# Arguments:
# +domain_nm         -- The name of the domain (FQDN).
#                       If you're creating a public hosted zone, this is the name 
#                       you have registered with your DNS registrar.
# +delegation_set_id --
# +caller_reference  -- Any unique string that identifies the request and that 
#                       allows failed CreateHostedZone requests to be retried 
#                       without the risk of executing the operation twice.
# +comment           -- A comment.
# Returns:      
#  The hosted zone identifier.  
#===============================================================================
function create_public_hosted_zone()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local domain_nm="${1}"
   local caller_reference="${2}"
   local comment="${3}"
   local hosted_zone_id

   hosted_zone_id="$(aws route53 create-hosted-zone \
                           --name "${domain_nm}" \
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
# sets, you must delete them before you can delete the hosted zone. If you try 
# to delete a hosted zone that contains other resource record sets, the request 
# fails, and Route 53 returns a HostedZoneNotEmpty error.
# If you delete a hosted zone, you can't undelete it. Instead, you must create a 
# new hosted zone and update the name servers for your domain registration, which 
# can require up to 48 hours to take effect. (If you delegated responsibility 
# for a subdomain to a hosted zone and you delete the child hosted zone, you must 
# update the name servers in the parent hosted zone.) In addition, if you delete 
# a hosted zone, someone could hijack the domain and route traffic to their own 
# resources using your domain name.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_id         -- The hosted zone identifier. 

# Returns:      
#  None
#===============================================================================
function delete_public_hosted_zone()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local hosted_zone_id="${1}"

   aws route53 delete-hosted-zone --id "${hosted_zone_id}"
   
   return 0
}

#===============================================================================
# Gets a hosted zone identifier.
#
# Globals:
#  None
# Arguments:
# +domain_nm            -- The name of the domain. 

# Returns:      
#  The hosted zone identifier, or blanc if not found.
#===============================================================================
function get_public_hosted_zone_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local domain_nm="${1}"
   local hosted_zone_id

   hosted_zone_id="$(aws route53 list-hosted-zones-by-name \
             --query "HostedZones[?contains(Name, '${domain_nm}')].{Id: Id}" \
             --output text)"
             
   echo "${hosted_zone_id}"          
   
   return 0
}

#===============================================================================
# Creates, changes, or deletes a resource record set, which contains 
# authoritative DNS information for a specified domain name or subdomain name. 
# When you submit a ChangeResourceRecordSets request, Route 53 propagates your 
# changes to all of the Route 53 authoritative DNS servers. While your changes 
# are propagating, GetChange returns a status of PENDING . When propagation is 
# complete, GetChange returns a status of INSYNC . Changes generally propagate 
# to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +hosted_zone_id -- the identifier of the hosted zone that contains the 
#                    resource record sets that you want to change.
# +domain_nm      -- the DNS domain name.
# +ip_address     -- the IP address associated to the domain.
# +record_type    -- SOA | A | TXT | NS | CNAME | MX | PTR | SRV | SPF | AAAA
# +action         -- CREATE | DELETE | UPSERT
# +comment        -- comment about the changes in this change batch request.
# Returns:      
#  The ID of the request.  
#===============================================================================
function __change_resource_record_sets()
{
   if [[ $# -lt 6 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local hosted_zone_id="${1}"
   local domain_nm="${2}"
   local ip_address="${3}"
   local record_type="${4}"
   local action="${5}"
   local comment="${6}"
   local change_batch
   local request_id
   
   change_batch="$(__create_change_batch "${domain_nm}" "${ip_address}" "${record_type}" "${action}" "${comment}")"

   request_id="$(aws route53 change-resource-record-sets \
                               --hosted-zone-id "${hosted_zone_id}" \
                               --change-batch "${change_batch}" \
                               --query ChangeInfo.Id \
                               --output text)"
                 
   echo "${request_id}"              

   return 0   
}

#===============================================================================
# Returns the current status of a change batch request.
# The status is one of the following values:
# PENDING indicates that the changes in this request  have  not  propagated  to 
# all Amazon Route 53 DNS servers. This is the initial status of all change 
# batch requests.
# INSYNC indicates that the changes have propagated to all Route 53 DNS servers.
#
# Globals:
#  None
# Arguments:
# +request_id      -- the ID of the request.
# Returns:      
#  The status of the request.  
#===============================================================================
function __get_change()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local request_id="${1}"
   local status
   
   status="$(aws route53 get-change \
                            --id="${request_id}" \
                            --query ChangeInfo.Status \
                            --output test)"
   echo "${status}"
   
   return 0
}

#===============================================================================
# Creates the change batch containing the list of change items to create, delete
# or update a resource record set.
#
# Globals:
#  None
# Arguments:
# +domain_nm   -- the DNS domain name.
# +ip_address  -- the IP address associated to the domain.
# +record_type -- SOA | A | TXT | NS | CNAME | MX | PTR | SRV | SPF | AAAA
# +action      -- CREATE | DELETE | UPSERT
# +comment     -- comment about the changes in this change batch request.
# Returns:      
#  None  
#=============================================================================== 
function __create_change_batch()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local domain_nm="${1}"
   local ip_address="${2}"
   local record_type="${3}"
   local action="${4}"
   local comment="${5}"
   local template
   
   template=$(cat <<-'EOF'
        {
           "Comment": "SEDcommentSED",
           "Changes": [
              {
                 "Action": "SEDactionSED",
                 "ResourceRecordSet": {
                    "Name": "SEDdomain_nameSED",
                    "Type": "SEDtypeSED",
                    "TTL": 120,
                    "ResourceRecords": [
                       {
                          "Value": "SEDip_addressSED"
                       }
                    ]
                 }
              }
           ]
        }
	EOF
   )
   
   change_batch_block="$(printf '%b\n' "${template}" \
                        | sed -e "s/SEDdomain_nameSED/${domain_nm}/g" \
                              -e "s/SEDip_addressSED/${ip_address}/g" \
                              -e "s/SEDtypeSED/${record_type}/g" \
                              -e "s/SEDcommentSED/${comment}/g" \
                              -e "s/SEDactionSED/${action}/g")" 
   
   echo "${change_batch_block}"
   
   return 0
}



## __create_change_batch 'maxmin.it' '192.0.0.3' 'A' 'CREATE' 'maxmin record' 







