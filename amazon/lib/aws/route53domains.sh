#===============================================================================
# When you register a domain, Amazon Route 53 does the following:
#
# Creates a Route 53 hosted zone that has the same name as the domain. 
# Route 53 assigns four name servers to your hosted zone and automatically 
# updates your domain registration with the names of these name servers.
# Enables autorenew, so your domain registration will renew automatically each 
# year. 
# Optionally enables privacy protection. If you don't enable privacy protection, 
# WHOIS queries return the information that you entered for the registrant, 
# admin, and tech contacts.
# If registration is successful, returns an operation ID that you can use to 
# track the progress and completion of the action. If the request is not 
# completed successfully, the domain registrant is notified by email.
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
# +request_file   -- the json file containing the data about the domain to 
#                    register
# Returns:      
#  Identifier for tracking the progress of the request.
#===============================================================================
function check_domain_availability()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local domain_nm="${1}"
   local availability
   
   ## route53domains webservice runs only in the us-east-1 Region.

   availability="$(aws route53domains check-domain-availability \
                         --region 'us-east-1' \
                         --domain-name "${domain_nm}" \
                         --output text)"          
  
   echo "${availability}"
   
   return 0
}  

#===============================================================================
# This function registers a domain.
#
# Globals:
#  None
# Arguments:
# +request_file   -- the json file containing the data about the domain to 
#                    register
# Returns:      
#  Identifier for tracking the progress of the request.
#===============================================================================
function register_domain()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local request_file="${1}"
   local operation_id

   ## route53domains webservice runs only in the us-east-1 Region.

   operation_id="$(aws route53domains register-domain \
                                 --region 'us-east-1' \
                                 --cli-input-json file://"${request_file}")" \
                                 --output text
  
   echo "${operation_id}"
   
   return 0
}   

#===============================================================================
# Get the date of submission of the request.
#
# Globals:
#  None
# Arguments:
# +operation_id    -- the identifier for the operation for which you want to get 
#                     the status. Route 53 returned the identifier in the 
#                     response to the original request.
# Returns:      
#  date of submission
#===============================================================================
function get_request_date()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local operation_id="${1}"
   local date
   
   ## route53domains webservice runs only in the us-east-1 Region.
   
   date="$(aws route53domains get-operation-detail \
                               --region 'us-east-1' \
                               --operation-id "${operation_id}" \
                               --query 'SubmittedDate' \
                               --output text)"
   echo "${date}"

   return 0
}  


#===============================================================================
# Returs the current status of an operation that is not completed.
#
# Globals:
#  None
# Arguments:
# +operation_id    -- the identifier for the operation for which you want to get 
#                     the status. Route 53 returned the identifier in the 
#                     response to the original request.
# Returns:      
#  status
#===============================================================================
function get_request_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local operation_id="${1}"
   local status
   
   ## route53domains webservice runs only in the us-east-1 Region.
   
   status="$(aws route53domains get-operation-detail \
                               --region 'us-east-1' \
                               --operation-id "${operation_id}" \
                               --query 'Status' \
                               --output text)"
   echo "${status}"
   
   return 0
} 
