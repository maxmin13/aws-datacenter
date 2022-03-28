#!/usr/bin/bash

# shellcheck disable=SC2034

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
# When you register a domain, Amazon route 53 does the following:
#
# 1) creates a route 53 hosted zone that has the same name as the domain. 
# 2) assigns four name servers to your hosted zone and automatically 
#    updates your domain registration with the names of these name servers.
# 3) enables autorenew, so your domain registration will renew automatically  
#    each year. Auto renewal can be explicitly set to false passing 
#    --auto-renew=false. 
# 4) Optionally Route 53 enables privacy protection. If you don't enable privacy 
#    protection, WHOIS queries return the information that you entered for the  
#    registrant, admin, and tech contacts.
#
# If registration is successful, returns an operation ID that you can use to 
# track the progress and completion of the action. If the request is not 
# completed successfully, the domain registrant is notified by email.
#
# route53domains webservice runs only in the us-east-1 region.
#
#===============================================================================

declare -r US_EAST_REGION='us-east-1'

#===============================================================================
# This operation checks the availability of one domain name. 
# Note that the availability status of a domain is pending, you must submit 
# another request to determine the availability of the domain name.
# You can register only domains designated as 'AVAILABLE'.
#
# Globals:
#  None
# Arguments:
# +domain_nm -- DNS domain name.
# Returns:      
#  whether the domain name is available for registering. The availability 
# status is returned in the global __RESULT variable, eg. UNAVAILABLE, 
# AVAILABLE.
#===============================================================================
function check_domain_availability()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r domain_nm="${1}"
   local availability=''
   
   availability="$(aws route53domains check-domain-availability \
                     --region "${US_EAST_REGION}" \
                     --domain-name "${domain_nm}" \
                     --output text)"          
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving domain availability.'
   fi
      
   __RESULT="${availability}"
                        
   return "${exit_code}" 
}

#===============================================================================
# The function returns true if the specified domain is associated with the 
# current AWS account, false otherwise.
#
# Globals:
#  None
# Arguments:
# +domain_nm -- DNS domain name.
# Returns:      
#  true/false string in the global __RESULT variable.
#===============================================================================
function check_domain_is_registered_with_the_account()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r domain_nm="${1}"
   local registered='false'
  
   set +e
   # throws an error if the domain is not registered with the current account. 
   aws route53domains get-domain-detail \
               --region "${US_EAST_REGION}" \
               --domain-name "${domain_nm}" > /dev/null 
   exit_code=$?
   set -e

   if [[ 0 -eq "${exit_code}" ]]
   then
      registered='true'
   fi
                           
   __RESULT="${registered}"
   
   return 0 
}

# Builds a request for the registration of an .it domain with no automatic renewal 
# after a year and with privacy protection enabled. The register_domain_request_it_template.json 
# file murst first be completed with the correct data by hand. 
function build_register_domain_request()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r domain_nm="${1}"
   local -r email_address="${2}"
   local register_domain_request=''
        
   register_domain_request="$(sed -e "s/SEDdns_domainSED/${domain_nm}/g" \
            -e "s/SEDemail_addressSED/${email_address}/g" \
               "${TEMPLATE_DIR}"/common/dns/register_domain_request_it_template.json)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: building register domain request.'
   else
     __RESULT="${register_domain_request}"
   fi
                        
   return ${exit_code}               
}

#===============================================================================
# The function returns true if the domain is a valid DNS domain, false 
# otherwise.
#
# Globals:
#  None
# Arguments:
# +domain_nm -- DNS domain name.
# Returns:      
#  true/false string in the global __RESULT variable.
#===============================================================================
function validate_dns_domain()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r domain_nm="${1}"
   local valid='false'
   
   # .it DNS name
   local -r domain_nm_regex='^(?!-)(?:[a-zA-Z0-9-]+\.)+it\.?$'

   set +e
   # throws an error if no match
   echo "${domain_nm}" | grep -oP "${domain_nm_regex}" > /dev/null
   exit_code=$?
   set -e

   if [[ 0 -eq "${exit_code}" ]]
   then
      valid='true'
   else
      echo 'ERROR: validating DNS name, not a valid .it DNS domain.'
   fi

   __RESULT="${valid}"
 
   return 0 
}

#===============================================================================
# This function submits a request to the AWS registrar for the registration of 
# the domain. 
#
# Globals:
#  None
# Arguments:
# +register_domain_request -- a JSON request containing the details of the  
#                             domain to register (see an example of a template 
#                             file is register-domain.json in the templates 
#                             directory).
# Returns:      
#  an operation identifier for tracking the progress of the request in the 
#  global __RESULT variable. 
#===============================================================================
function register_domain()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r register_domain_request="${1}"
   local operation_id=''

   if [[ ! -f "${register_domain_request}" ]]
   then
      echo 'ERROR: request file not found.'
      return 128
   fi

   operation_id="$(aws route53domains register-domain \
                     --region "${US_EAST_REGION}" \
                     --cli-input-json file://"${register_domain_request}" \
                     --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: registering the domain.'
   else
      __RESULT="${operation_id}"
   fi                  
  
   return "${exit_code}"
}   

#===============================================================================
# This operation replaces the current set of name servers for the domain with 
# the specified set of name servers. If successful, this operation returns 
# an operation ID that you can use to track the progress and completion of 
# the action.
#
# Globals:
#  None
# Arguments:
# +domain_nm    -- DNS domain name.
# +name_servers -- the list of the new name servers, eg:
#                  ns-1.awsdns-01.org ns-2.awsdns-02.co.uk ns-3.awsdns-03.net 
#                  ns-4.awsdns-04.com
# Returns:      
#  an operation identifier for tracking the progress of the request in the
#  __RESULT global variable.
#===============================================================================
function update_domain_registration_name_servers()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r domain_nm="${1}"
   local -r name_servers="${2}"
   local operation_id=''
   local name_servers_list=''
   
   # make the list into a Json list.
   __create_name_servers_list "${name_servers}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: updating domain registration name servers 1.'
      return "${exit_code}"
   fi

   name_servers_list="${__RESULT}"
   __RESULT=''

   echo "DEBUG: ${name_servers_list}"

   # assign the nameservers from the hosted zone to the domain.
   operation_id="$(aws route53domains update-domain-nameservers \
                     --region "${US_EAST_REGION}" \
                     --domain-name "${domain_nm}" \
                     --nameservers "${name_servers_list}" \
                     --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: updating domain registration name servers 2.'
   else
      __RESULT="${operation_id}"
   fi                  
   
   return "${exit_code}"
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
#  the operation's current status or blanc if the operation has not been 
#  submitted, in the __RESULT global variable. 
#===============================================================================
function get_request_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local exit_code=0
   local -r request_name="${1}"
   local request_status=''
   
   request_status="$(aws route53domains list-operations \
                     --region "${US_EAST_REGION}" \
                     --query "Operations[?Type==${request_name}].Status" \
                     --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting request status.'
   else
      __RESULT="${request_status}"
   fi                  
  
   return "${exit_code}"
} 


#===============================================================================
# Transforms a string containing four name server names separated by a white  
# spaces in a JSON list object. 
#
# Globals:
#  None
# Arguments:
# +name_servers -- a string with the names of four name servers separated by 
#                  white spaces.
# Returns:      
#  a JSON list object containing the names of four name servers in the __RESULT 
#  global variable.  
#=============================================================================== 
function __create_name_servers_list()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local -r name_servers="${1}"
   local servers=''
   local template=''
   local size=''
   local name_servers_list=''

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

   read -ra servers <<< "${name_servers}"  
   size="${#servers[@]}"

   if [[ ! 4 -eq "${size}" ]]
   then
      echo 'ERROR: not a list of 4 name servers.'
      return 128
   fi
   
   name_servers_list="$(printf '%b\n' "${template}" \
                  | sed -e "s/SEDname_server1SED/${servers[0]}/g" \
                        -e "s/SEDname_server2SED/${servers[1]}/g" \
                        -e "s/SEDname_server3SED/${servers[2]}/g" \
                        -e "s/SEDname_server4SED/${servers[3]}/g")" 
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating the JSON list.'
   else
      __RESULT="${name_servers_list}"
   fi                  
  
   return "${exit_code}"
}
