#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: elb.sh
#   DESCRIPTION: The script contains functions that use AWS AMI client to make 
#                calls to AWS
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Returns the load balancer DNS name, or an empty string if the load balancer 
# doesn't exist.
#
# Globals:
#  None
# Arguments:
# +lbal_nm -- the name of the load balancer.
# Returns:      
#  the load balancer DNS name, or blanc if the load balancer is not found.  
#===============================================================================
function get_loadbalancer_dns_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local lbal_nm="${1}"
   local lbal_dns_nm
 
   lbal_dns_nm="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?LoadBalancerName=='${lbal_nm}'].DNSName" \
       --output text)"
 
   echo "${lbal_dns_nm}"
 
   return 0
}

#===============================================================================
# Returns the load balancer hosted zone ID or an empty string if the load 
# balancer isn't found.
#
# Globals:
#  None
# Arguments:
# +lbal_nm -- the name of the load balancer.
# Returns:      
#  the load balancer hosted zone ID, or blanc if the load balancer is not found.  
#===============================================================================
function get_loadbalancer_hosted_zone_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local lbal_nm="${1}"
   local lbal_dns_nm_nm=''
 
   lbal_dns_nm_nm="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?LoadBalancerName=='${lbal_nm}'].CanonicalHostedZoneNameID" \
       --output text)"
 
   echo "${lbal_dns_nm_nm}"
 
   return 0
}

#===============================================================================
# Creates a classic load balancer that listens on HTTP 80 port and forwards the 
# requests to the instances on port 8070.  
#
# Globals:
#  None
# Arguments:
# +lbal_nm   -- the load balancer name.
# +sg_id     -- the load balancer's security group identifier.
# +subnet_id -- the load balancer's subnet identifier.
# Returns:      
#  None  
#===============================================================================
function create_http_loadbalancer()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local lbal_nm="${1}"
   local sgp_id="${2}"
   local subnet_id="${3}"
 
   aws elb create-load-balancer \
       --load-balancer-name "${lbal_nm}" \
       --security-groups "${sgp_id}" \
       --subnets "${subnet_id}" \
       --region "${DTC_DEPLOY_REGION}" \
       --listener LoadBalancerPort="${LBAL_HTTP_PORT}",InstancePort="${SRV_WEBPHP_APACHE_WEBSITE_HTTP_PORT}",Protocol=http,InstanceProtocol=http > /dev/null
 
   return 0
}

#===============================================================================
# Specifies the health check settings to use when evaluating the health state of 
# your EC2 instances. Each monitored instance is expected to provide a 
# endpoint receable by the Load Balancer, ex: HTTP:8090/elb.htm.
# The endpoint must return 'ok' response.
# Each registered instance must allow access to the load balancer ping in the 
# security group.
#
# Globals:
#  None
# Arguments:
# +lbal_nm -- the load balancer name.
# Returns:      
#  None  
#===============================================================================
function configure_loadbalancer_health_check()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local lbal_nm="${1}"
 
   aws elb configure-health-check \
       --load-balancer-name "${lbal_nm}" \
       --health-check Target=HTTP:"${SRV_WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT}"/elb.htm,Interval=10,Timeout=5,UnhealthyThreshold=2,HealthyThreshold=2 > /dev/null
 
   return 0
}

#===============================================================================
# Deletes the specified load balancer. After deletion, the name and associated 
# DNS record of the load balancer no longer exist and traffic sent to any of its 
# IP addresses is no longer delivered to the instances.
#
# Globals:
#  None
# Arguments:
# +lbal_nm -- the load balancer name.
# Returns:      
#  None  
#===============================================================================
function delete_loadbalancer()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local lbal_nm="${1}"
 
   aws elb delete-load-balancer --load-balancer-name "${lbal_nm}" 

   return 0
}

#===============================================================================
# Adds the specified instances to the specified Load Balancer.
# The instance must be a running instance in the same network as the load
# balancer. After the instance is registered, it starts receiving traffic and
# requests from the Load Balancer.
#
# Globals:
#  None
# Arguments:
# +lbal_nm     -- load balancer name.
# +instance_id -- the instance ID of the box under load balancer.
# Returns:      
#  None  
#===============================================================================
function register_instance_with_loadbalancer()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local lbal_nm="${1}"
   local instance_id="${2}"
   
   aws elb register-instances-with-load-balancer \
       --load-balancer-name "${lbal_nm}" \
       --instances "${instance_id}" > /dev/null
   
   return 0
}

#===============================================================================
# Deregisters the specified instance from the load balancer. The deregistered
# instance no longer receives traffic from the load balancer.
#
# Globals:
#  None
# Arguments:
# +lbal_nm     -- load balancer name.
# +instance_id -- the instance ID.
# Returns:      
#  None  
#===============================================================================
function deregister_instance_from_loadbalancer()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local lbal_nm="${1}"
   local instance_id="${2}"
   
   aws elb deregister-instances-from-load-balancer \
       --load-balancer-name "${lbal_nm}" \
       --instances "${instance_id}" > /dev/null
   
   return 0
}

#===============================================================================
# Checks if an instance is registered with a Load Balancer.
#
# Globals:
#  None
# Arguments:
# +lbal_nm     -- load balancer name.
# +instance_id -- the instance ID.
# Returns:      
#  true/false value.  
#===============================================================================
function check_instance_is_registered_with_loadbalancer()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local lbal_nm="${1}"
   local instance_id="${2}"
   local is_registered='false'
   local lbal_name=''
   
   lbal_name="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?contains(LoadBalancerName, '${lbal_nm}') && contains(Instances[].InstanceId, '${instance_id}')].{LoadBalancerName: LoadBalancerName}" \
       --output text)"  
       
   if [[ -n "${lbal_name}" ]]  
   then
      is_registered='true'
   fi                     
            
   echo "${lbal_name}"
   
   return 0
}
