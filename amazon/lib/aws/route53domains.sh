#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
# When you register a domain, Amazon route 53 does the following:
#
# Creates a route 53 hosted zone that has the same name as the domain. 
# route 53 assigns four name servers to your hosted zone and automatically 
# updates your domain registration with the names of these name servers.
# Enables autorenew, so your domain registration will renew automatically each 
# year. 
# Optionally enables privacy protection. If you don't enable privacy protection, 
# WHOIS queries return the information that you entered for the registrant, 
# admin, and tech contacts.
# If registration is successful, returns an operation ID that you can use to 
# track the progress and completion of the action. If the request is not 
# completed successfully, the domain registrant is notified by email.
#
# route53domains webservice runs only in the us-east-1 Region.
#
#===============================================================================

#===============================================================================
# This operation checks the availability of one domain name. 
# Note that the availability status of a domain is pending, you must submit 
# another request to determine the availability of the domain name.
# You can register only domains designated as 'AVAILABLE'.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm    -- The hosted zone name, this is the name you have 
#                       registered with your DNS registrar.
# Returns:      
#  Identifier for tracking the progress of the request.
#===============================================================================
function check_domain_availability()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local hosted_zone_nm="${1}"
   local availability
   
   availability="$(aws route53domains check-domain-availability \
                         --region 'us-east-1' \
                         --domain-name "${hosted_zone_nm}" \
                         --output text)"          
  
   echo "${availability}"
   
   return 0
}

#===============================================================================
# This operation returns detailed information about a specified domain that is 
# associated with the current AWS account.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm    -- The hosted zone name, this is the name you have 
#                       registered with your DNS registrar.
# Returns:      
#  Identifier for tracking the progress of the request.
#===============================================================================
function check_domain_is_registered_with_the_account()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local hosted_zone_nm="${1}"
   local registered
   
   registered="$(aws route53domains get-domain-detail \
                          --region 'us-east-1' \
                          --domain-name "${hosted_zone_nm}" \
                          --query 'DomainName' \
                          --output text)"
   
   echo "${registered}"
   
   return 0
}

#===============================================================================
# This function registers a domain.
#
# Globals:
#  None
# Arguments:
# +request_file   -- the file containing the details of the domain to register.
# Returns:      
#  Identifier for tracking the progress of the request.
#===============================================================================
function register_domain()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local request_file="${1}"
   local operation_id

   operation_id="$(aws route53domains register-domain \
                                 --region 'us-east-1' \
                                 --cli-input-json file://"${request_file}" \
                                 --output text)"
  
   echo "${operation_id}"
   
   return 0
}   

#===============================================================================
# This operation replaces the current set of name servers for the domain with 
# the specified set of name servers.
# If successful, this operation returns an operation ID that you can use to 
# track the progress and completion of the action. If the request is not 
# completed successfully, the domain registrant will be notified by email.
#
# Globals:
#  None
# Arguments:
# +hosted_zone_nm    -- the hosted zone name, this is the name you have 
#                       registered with your DNS registrar.
# +nameservers       -- the list of the new name servers, eg:
#                       ns-1.awsdns-01.org ns-2.awsdns-02.co.uk ns-3.awsdns-03.net ns-4.awsdns-04.com
# Returns:      
#  Identifier for tracking the progress of the request.
#===============================================================================
function update_domain_registration_name_servers()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local hosted_zone_nm="${1}"
   local nameservers="${2}"
   local operation_id
   local request_body
   
   request_body="$(__create_update_name_servers_request "${nameservers}")"

   operation_id="$(aws route53domains update-domain-nameservers \
                                       --region 'us-east-1' \
                                       --domain-name "${hosted_zone_nm}" \
                                       --nameservers "${request_body}" \
                                       --output text)"
  
   echo "${operation_id}"
   
   return 0
}   

#===============================================================================
# Returs the current status of an operation.
#
# Globals:
#  None
# Arguments:
# +request_name -- the name of the operation, 
#                  eg: REGISTER_DOMAIN, UPDATE_NAMESERVER.
# Returns:      
#  The operation's current status or blanc if the operation has not been 
#  submitted 
#===============================================================================
function get_request_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local request_name="${1}"
   local status
   
   status="$(aws route53domains list-operations \
                               --region 'us-east-1' \
                               --query "Operations[?Type==${request_name}].Status" \
                               --output text)"
   echo "${status}"
   
   return 0
} 

#===============================================================================
# Creates the change batch request to create, delete or update a record type A.
# A-records are the DNS server equivalent of the hosts file - a simple domain 
# name to IP-address mapping. 
# Changes generally propagate to all route 53 name servers within 60 seconds. 
#
# Globals:
#  None
# Arguments:
# +name_server_list   -- a string with the names of four name servers.
# Returns:      
#  The change batch containing the changes to apply to a hosted zone.  
#=============================================================================== 
function __create_update_name_servers_request()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local name_server_list="${1}"
   local template
   local servers=(${name_server_list})
   local size
   local nms
   
   template=$(cat <<-'EOF'
        [
          {
            "Name": "SEDname_server1SED"
          },
          {
            "Name": "SEDname_server2SED"
          },
          {
            "Name": "SEDname_server3SED"
          },
          {
            "Name": "SEDname_server4SED"
          }
        ]
	EOF
   )
   
   # Must be 4 server names
   
   size="${#servers[@]}"
   
   if [[ ! 4 -eq "${size}" ]]
   then
      echo 'ERROR: not a list of 4 name servers'
      return 1
   fi
   
   change_batch="$(printf '%b\n' "${template}" \
                        | sed -e "s/SEDname_server1SED/${servers[0]}/g" \
                              -e "s/SEDname_server2SED/${servers[1]}/g" \
                              -e "s/SEDname_server3SED/${servers[2]}/g" \
                              -e "s/SEDname_server4SED/${servers[3]}/g")" 
   
   echo "${change_batch}"
   
   return 0
}

## update_domain_registration_name_servers 'maxmin.it'    'ns-1.awsdns-01.org  ns-2.awsdns-02.co.uk        ns-3.awsdns-03.net  ns-4.awsdns-04.com'
##__create_update_name_servers_request 'ns-1.awsdns-01.org  ns-2.awsdns-02.co.uk        ns-3.awsdns-03.net  ns-4.awsdns-04.com'
