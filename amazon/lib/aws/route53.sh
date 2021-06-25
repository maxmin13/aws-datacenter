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
# +hosted_zone_nm    -- The hosted zone name, this is the name you have registered with your DNS 
#                       registrar.
# +caller_reference  -- Any unique string that identifies the request and that 
#                       allows failed CreateHostedZone requests to be retried 
#                       without the risk of executing the operation twice.
# +comment           -- Any comments that you want to include about the hosted 
#                       zone.
# Returns:      
#  The hosted zone identifier.  
#===============================================================================
function create_hosted_zone()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_nm="${1}"
   local caller_reference="${2}"
   local comment="${3}"
   local hosted_zone_id

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
# +hosted_zone_nm -- The hosted zone name, this is the name you have registered 
#                    with your DNS registrar.
# Returns:      
#  None
#===============================================================================
function delete_hosted_zone()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_nm="${1}"
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   aws route53 delete-hosted-zone --id "${hosted_zone_id}"
   
   return 0
}

#===============================================================================
# Checks if a hosted zone exits by returning its name, or blanc if not found.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm -- The hosted zone name, this is the name you have registered 
#                    with your DNS registrar.
# Returns:      
#  The hosted zone's name if it exists, blanc otherwise.
#===============================================================================
function check_hosted_zone_exists() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_nm="${1}"
   local exists
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   exists="$(aws route53 get-hosted-zone --id "${hosted_zone_id}" \
                                         --query HostedZone.Name \
                                         --output text)"
   
   echo "${exists}"
   
   return 0
}

#===============================================================================
# Returns a string containing a hosted zone name servers.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm -- The hosted zone name, this is the name you have registered 
#                    with your DNS registrar.
# Returns:      
#  A string representing the hosted zone name servers.
#  ex: ns-128.awsdns-16.com ns-1930.awsdns-49.co.uk ns-752.awsdns-30.net ns-1095.awsdns-08.org
#===============================================================================
function get_hosted_zone_name_servers() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_nm="${1}"
   local name_servers
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   name_servers="$(aws route53 get-hosted-zone \
                                  --id "${hosted_zone_id}" \
                                  --query DelegationSet.NameServers[*] \
                                  --output text)"
   
   echo "${name_servers}"
   
   return 0
}

#===============================================================================
# Returs the name of the record if the record is present in the hosted zone.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm     -- The hosted zone name, this is the name you have 
#                        registered with your DNS registrar.
# +sub_domain_nm      -- the alias sub-domain name, eg. www
# Returns:      
#  The name of the record, or blanc if not found.  
#===============================================================================
function check_hosted_zone_has_record() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_nm="${1}"
   local sub_domain_nm='-'
   local domain
   local record
   
   if [[ $# -eq 2 ]]
   then
      sub_domain_nm="${2}"
      domain="${sub_domain_nm}"."${hosted_zone_nm}"
   else
      # TLD
      domain="${hosted_zone_nm}"
   fi
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   record="$(aws route53 list-resource-record-sets \
                     --hosted-zone-id "${hosted_zone_id}" \
                     --query "ResourceRecordSets[?contains(Name,'${domain}')].Name" \
                     --output text)"
                     
   echo "${record}"
   
   return 0
}

#===============================================================================
# Returs the IP address associated with a record or an empty string if the 
# record doesn't have one.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm     -- The hosted zone name, this is the name you have 
#                        registered with your DNS registrar.
# +sub_domain_nm      -- the alias sub-domain name, eg. www
# Returns:      
#  The IP address associated with the record, or blanc if not found.  
#===============================================================================
function get_record_ip_address() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_nm="${1}"
   local sub_domain_nm='-'
   local domain
   local ip_address
   
   if [[ $# -eq 2 ]]
   then
      sub_domain_nm="${2}"
      domain="${sub_domain_nm}"."${hosted_zone_nm}"
   else
      # TLD
      domain="${hosted_zone_nm}"
   fi
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   ip_address="$(aws route53 list-resource-record-sets \
                     --hosted-zone-id "${hosted_zone_id}" \
                     --query "ResourceRecordSets[?contains(Name,'${domain}')].ResourceRecords[*].Value" \
                     --output text)"
                     
   echo "${ip_address}"
   
   return 0
}

#===============================================================================
# Returs the DNS name associated with a record or an empty string if the 
# record doesn't have one.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm     -- The hosted zone name, this is the name you have 
#                        registered with your DNS registrar.
# +sub_domain_nm      -- the alias sub-domain name, eg. www
# Returns:      
#  The DNS name associated with the record, or blanc if not found.  
#===============================================================================
function get_record_dns_name() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_nm="${1}"
   local sub_domain_nm='-'
   local domain
   local dns_nm
   
   if [[ $# -eq 2 ]]
   then
      sub_domain_nm="${2}"
      domain="${sub_domain_nm}"."${hosted_zone_nm}"
   else
      # TLD
      domain="${hosted_zone_nm}"
   fi
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   dns_nm="$(aws route53 list-resource-record-sets \
                     --hosted-zone-id "${hosted_zone_id}" \
                     --query "ResourceRecordSets[?contains(Name,'${domain}')].AliasTarget.DNSName" \
                     --output text)"
                     
   echo "${dns_nm}"
   
   return 0
}

#===============================================================================
# Returs the Hosted Zone ID associated with a record or an empty string if the 
# record doesn't have one.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm     -- The hosted zone name, this is the name you have 
#                        registered with your DNS registrar.
# +sub_domain_nm      -- the alias sub-domain name, eg. www
# Returns:      
#  The Hosted Zone identifier associated with the record, or blanc if not found.  
#===============================================================================
function get_record_hosted_zone_id() 
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_nm="${1}"
   local sub_domain_nm='-'
   local domain
   local dns_nm
   
   if [[ $# -eq 2 ]]
   then
      sub_domain_nm="${2}"
      domain="${sub_domain_nm}"."${hosted_zone_nm}"
   else
      # TLD
      domain="${hosted_zone_nm}"
   fi
   
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   dns_nm="$(aws route53 list-resource-record-sets \
                     --hosted-zone-id "${hosted_zone_id}" \
                     --query "ResourceRecordSets[?contains(Name,'${domain}')].AliasTarget.HostedZoneId" \
                     --output text)"
                     
   echo "${dns_nm}"
   
   return 0
}

#===============================================================================
# Adds an A-record to a hosted zone.
# If the subdomain is not passed, the domain is considered a top level domain.
# A-records are the DNS server equivalent of the hosts file - a simple domain 
# name to IP-address mapping. 
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +ip_address       -- the IP address associated to the domain name.
# +hosted_zone_nm   -- the hosted zone name, this is the name you have 
#                      registered with the DNS registrar.
# +sub_domain_nm    -- the alias sub-domain name, eg. www. 
# Returns:      
#  The ID of the request.  
#===============================================================================
function create_record()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local ip_address="${1}"
   local hosted_zone_nm="${2}" 
   local sub_domain_nm='-' 
   local domain
   local request_id
   
   if [[ $# -eq 3 ]]
   then
      sub_domain_nm="${3}"
      domain="${sub_domain_nm}"."${hosted_zone_nm}"
   else
      # TLD
      domain="${hosted_zone_nm}"
   fi
                                                           
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   request_body="$(__create_type_A_change_batch "${domain}" \
                                                "${ip_address}" \
                                                'CREATE' \
                                                "A Record for ${ip_address}")"
                                                  
   ## Submit the hosted zone changes. 
   request_id="$(__submit_change_batch "${hosted_zone_id}" "${request_body}")"                                              
   
   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Deletes a record in a hosted zone.
# If the subdomain is not passed, the domain is considered a top level domain.
# Changes to a hosted zoned generally propagate to all Route 53 name servers 
# within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +sub_domain_nm      -- the alias sub-domain name, eg. www
# +hosted_zone_nm     -- The hosted zone name, this is the name you have 
#                        registered with your DNS registrar.
# +ip_address         -- the IP address associated to the domain name.
# Returns:      
#  The ID of the request.  
#===============================================================================
function delete_record()
{
  if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local ip_address="${1}"
   local hosted_zone_nm="${2}" 
   local sub_domain_nm='-' 
   local domain
   local request_id
   
   if [[ $# -eq 3 ]]
   then
      sub_domain_nm="${3}"
      domain="${sub_domain_nm}"."${hosted_zone_nm}"
   else
      # TLD
      domain="${hosted_zone_nm}"
   fi
                                                           
   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
   
   request_body="$(__create_type_A_change_batch "${domain}" \
                                                "${ip_address}" \
                                                'DELETE' \
                                                "A Record for ${ip_address}")"
                                                  
   ## Submit the hosted zone changes. 
   request_id="$(__submit_change_batch "${hosted_zone_id}" "${request_body}")"                                              
   
   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Adds an alias record to a hosted zone.
# If the subdomain is not passed, the domain is considered a top level domain.
# A Canonical Name record (abbreviated as CNAME record) is a type of resource 
# record in the Domain Name System (DNS) that maps one domain name (an alias) to 
# another (the canonical name).
# Changes generally propagate to all Route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +target_hosted_zone_id -- the hosted zone identifier of the referred domain. 
# +target_domain_nm      -- the domain name referred by the alias.
# +hosted_zone_nm        -- the alias's hosted zone, this is the name you have  
#                           registered with your DNS registrar.
# +sub_domain_nm         -- the alias sub-domain name, eg. www .
# Returns:      
#  The ID of the request.  
#===============================================================================
function create_alias_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local target_hosted_zone_id="${1}"
   local target_domain_nm="${2}"  
   local hosted_zone_nm="${3}"
   local sub_domain_nm='-'
   local hosted_zone_id
   local request_body
   local request_id
   local domain
   
   echo target_hosted_zone_id $target_hosted_zone_id
   echo target_domain_nm $target_domain_nm 
   echo hosted_zone_nm $hosted_zone_nm
   
   if [[ $# -eq 4 ]]
   then
      sub_domain_nm="${4}"
      
      echo sub_domain_nm $sub_domain_nm
      
      domain="${sub_domain_nm}"."${hosted_zone_nm}"
   else
      # TLD
      domain="${hosted_zone_nm}"
   fi

   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
    
   request_body="$(__create_alias_change_batch "${domain}" \
                                               "dualstack.${target_domain_nm}" \
                                               "${target_hosted_zone_id}" \
                                               'CREATE' \
                                               "Alias record for ${sub_domain_nm}.${hosted_zone_nm}")"
                                                  
   ## Submit the changes to the hosted zone. 
   request_id="$(__submit_change_batch "${hosted_zone_id}" "${request_body}")"   
                                        
   echo "${request_id}"
   
   return 0
}

#===============================================================================
# Deletes an alias record in a hosted zone.
# If the subdomain is not passed, the domain is considered a top level domain.
# Changes to a hosted zoned generally propagate to all Route 53 name servers 
# within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +target_hosted_zone_id -- the hosted zone identifier of the referred domain. 
# +target_domain_nm      -- the domain name referred by the alias.
# +hosted_zone_nm        -- the alias's hosted zone, this is the name you have  
#                           registered with your DNS registrar.
# +sub_domain_nm         -- the alias sub-domain name, eg. www . 
# Returns:      
#  The ID of the request.  
#===============================================================================
function delete_alias_record()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local target_hosted_zone_id="${1}"
   local target_domain_nm="${2}"  
   local hosted_zone_nm="${3}"
   local sub_domain_nm='-' 
   local hosted_zone_id
   local request_body
   local request_id
   local domain
   
   if [[ $# -eq 4 ]]
   then
      sub_domain_nm="${4}"
      domain="${sub_domain_nm}"."${hosted_zone_nm}"
   else
      # TLD
      domain="${hosted_zone_nm}"
   fi

   hosted_zone_id="$(__get_hosted_zone_id "${hosted_zone_nm}")"
    
   request_body="$(__create_alias_change_batch "${domain}" \
                                               "dualstack.${target_domain_nm}" \
                                               "${target_hosted_zone_id}" \
                                               'DELETE' \
                                               "Alias record for ${sub_domain_nm}.${hosted_zone_nm}")"
                                                  
   ## Submit the changes to the hosted zone. 
   request_id="$(__submit_change_batch "${hosted_zone_id}" "${request_body}")"   
                                        
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
# +request_id      -- the ID of the request.
# Returns:      
#  The status of the request.  
#===============================================================================
function get_record_request_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local request_id="${1}"
   local status
   
   status="$(__get_change_batch_request_status "${request_id}")"
   echo "${status}"
   
   return 0
}

#===============================================================================
# Returns the current status of a change batch request.
# The status is one of the following values:
# PENDING indicates that the changes in this request have not propagated to 
# all Amazon Route 53 DNS servers. This is the initial status of all change 
# batch requests.
# INSYNC indicates that the changes have propagated to all Route 53 DNS servers.
#
# Globals:
#  None
# Arguments:
# +cb_request_id      -- the ID of the change batch request.
# Returns:      
#  The status of the request.  
#===============================================================================
function __get_change_batch_request_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local cb_request_id="${1}"
   local status
   
   status="$(aws route53 get-change --id="${cb_request_id}" \
                                    --query ChangeInfo.Status \
                                    --output text)"
   echo "${status}"
   
   return 0
}

#===============================================================================
# Creates the change batch request to create, delete or update a record type A.
# A-records are the DNS server equivalent of the hosts file - a simple domain 
# name to IP-address mapping. 
#
# Globals:
#  None
# Arguments:
# +domain_nm   -- the DNS domain name.
# +ip_address  -- the IP address associated to the domain.
# +action      -- CREATE | DELETE | UPSERT
# +comment     -- comment about the changes in this change batch request.
# Returns:      
#  The change batch containing the changes to apply to a hosted zone.  
#=============================================================================== 
function __create_type_A_change_batch()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local domain_nm="${1}"
   local ip_address="${2}"
   local action="${3}"
   local comment="${4}"
   local template
   
   template=$(cat <<-'EOF'
        {
           "Comment": "SEDcommentSED",
           "Changes": [
              {
                 "Action": "SEDactionSED",
                 "ResourceRecordSet": {
                    "Name": "SEDdomain_nameSED",
                    "Type": "A",
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
#  The change batch containing the changes to apply to a hosted zone.  
#=============================================================================== 
function __create_alias_change_batch()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi

   local domain_nm="${1}"
   local target_domain_nm="${2}"
   local target_hosted_zone_id="${3}"
   local action="${4}"
   local comment="${5}"
   local template
   
   template=$(cat <<-'EOF' 
        {
             "Comment": "SEDcommentSED",
             "Changes": [
                           {
                              "Action": "SEDactionSED",
                              "ResourceRecordSet": 
                                 {
                                    "Name": "SEDdomain_nmSED",
                                    "Type": "A",
                                    "AliasTarget":
                                       {
                                            "HostedZoneId": "SEDtarget_hosted_zone_idSED",
                                            "DNSName": "SEDtarget_domain_nmSED",
                                            "EvaluateTargetHealth": false
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
#  The change batch request identifier.  
#=============================================================================== 
function __submit_change_batch()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local hosted_zone_id="${1}"
   local request_body="${2}"
   local request_id

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
# +hosted_zone_nm -- The hosted zone name, this is the name you have registered  
#                    with the DNS registrar. 

# Returns:      
#  The hosted zone identifier. 
#===============================================================================
function __get_hosted_zone_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      exit 1
   fi
   
   local domain_nm="${1}"
   local hosted_zone_id

   hosted_zone_id="$(aws route53 list-hosted-zones-by-name \
             --query "HostedZones[?contains(Name, '${domain_nm}')].{Id: Id}" \
             --output text)"
             
   if [[ -z "${hosted_zone_id}" ]]
   then
     echo 'ERROR: hosted zone not found'
     exit 1
   fi          
             
   echo "${hosted_zone_id}"          
   
   return 0
}

## create_hosted_zone 'maxmin.it' 'maxmin_it_caller_reference' 'maxmin.it public hosted zone'
## delete_hosted_zone 'maxmin.it' 
## check_hosted_zone_exists 'maxmin.it'
## get_hosted_zone_name_servers 'maxmin.it'

## get_record_ip_address 'maxmin.it' 'admin'
## get_record_ip_address 'maxmin.it' 'www'
## get_record_dns_name 'maxmin.it' 'admin'
## get_record_dns_name 'maxmin.it' 'www'
## get_record_hosted_zone_id 'maxmin.it' 'www'

## create_record '18.203.73.111' 'maxmin.it' 'admin' 
## delete_record '18.203.73.111' 'maxmin.it' 'admin' 
## create_record '18.203.73.111' 'maxmin.it' 'www' 
## delete_record '18.203.73.111' 'maxmin.it' 'www' 
## create_record '18.203.73.111' 'maxmin.it' 
## delete_record '18.203.73.111' 'maxmin.it'

## get_record_request_status '/change/C08567412987M8ULD7QKI'
## check_hosted_zone_has_record 'maxmin.it' 'admin'

## create_alias_record 'Z32O12XQLNTSW2' '1203266565.eu-west-1.elb.amazonaws.com' 'maxmin.it' 'www'
## delete_alias_record 'Z32O12XQLNTSW2' '1203266565.eu-west-1.elb.amazonaws.com' 'maxmin.it' 'www'
## create_alias_record 'Z32O12XQLNTSW2' 'elbmaxmin-458631052.eu-west-1.elb.amazonaws.com' 'maxmin.it' 'abc' 
## delete_alias_record 'Z32O12XQLNTSW2' 'elbmaxmin-458631052.eu-west-1.elb.amazonaws.com' 'maxmin.it' 'abc'

## get_record_request_status '/change/C08567412987M8ULD7QKI'
## check_hosted_zone_has_record 'maxmin.it' 'www' 
## check_hosted_zone_has_record 'maxmin.it' 

## __create_type_A_change_batch 'webphp1.maxmin.it' '34.242.102.242' 'A' 'CREATE' 'admin website' 
# __create_alias_change_batch 'www.maxmin.it' 'dualstack.elbmaxmin-1613735089.eu-west-1.elb.amazonaws.com' 'Z32O12XQLNTSW2' 'CREATE' 'elb alias'

# __submit_change_batch '/hostedzone/Z07357981HPLU4QUR6272' 'file:///home/maxmin/Projects/datacenter/amazon/lib/aws/request_body.json'

## __get_change_batch_request_status '/change/C0398056OWZA90PICZPC'

## __get_hosted_zone_id 'maxmin.it'
## __get_hosted_zone_id 'elbmaxmin-450194799'




