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
# Returns the load balancer DNS name or, if the load balancer doesn't exist, an
# empty string.
#
# Globals:
#  None
# Arguments:
# +loadbalancer_nm     -- The load balancer name.
# Returns:      
#  The load balancer DNS name, or blanc if the Looad Balancer is not found.  
#===============================================================================
function get_loadbalancer_dns_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local loadbalancer_nm="${1}"
   local elb_dns
 
   elb_dns="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?LoadBalancerName=='${loadbalancer_nm}'].DNSName" \
       --output text)"
 
   echo "${elb_dns}"
 
   return 0
}

#===============================================================================
# Returns the load balancer DNS hosted zone identifier or, if the load balancer 
# doesn't exist, an empty string.
#
# Globals:
#  None
# Arguments:
# +loadbalancer_nm     -- The load balancer name.
# Returns:      
#  The ELB hosted zone identifier, or blanc if the ELB is not found.  
#===============================================================================
function get_loadbalancer_dns_hosted_zone_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local loadbalancer_nm="${1}"
   local elb_dns
 
   elb_dns="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?LoadBalancerName=='${loadbalancer_nm}'].CanonicalHostedZoneNameID" \
       --output text)"
 
   echo "${elb_dns}"
 
   return 0
}

#===============================================================================
# Creates a Classic Load Balancer. 
# The Load Balander listens on 443 port and forwards the requests to 8070 port.
# Elastic Load Balancers support sticky sessions.  
#
# Globals:
#  None
# Arguments:
# +loadbalancer_nm     -- The load balancer name.
# +cert_arn            -- The Amazon Resource Name (ARN) specifying the server
#                         certificate.
# +sg_id               -- The Loadbalancer's security group identifier.
# +subnet_id           -- The Loadbalancer's subnet identifier.
# Returns:      
#  None  
#===============================================================================
function create_loadbalancer()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local loadbalancer_nm="${1}"
   local cert_arn="${2}"
   local sg_id="${3}"
   local subnet_id="${4}"
 
   aws elb create-load-balancer \
       --load-balancer-name "${loadbalancer_nm}" \
       --security-groups "${sg_id}" \
       --subnets "${subnet_id}" \
       --region "${DTC_DEPLOY_REGION}" \
       --listener LoadBalancerPort="${LBAL_PORT}",InstancePort="${SRV_WEBPHP_APACHE_WEBSITE_HTTP_PORT}",Protocol=https,InstanceProtocol=http,SSLCertificateId="${cert_arn}" >> /dev/null
 
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
# +loadbalancer_nm     -- The load balancer name.
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

   local loadbalancer_nm="${1}"
 
   aws elb configure-health-check \
       --load-balancer-name "${loadbalancer_nm}" \
       --health-check Target=HTTP:"${SRV_WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT}"/elb.htm,Interval=10,Timeout=5,UnhealthyThreshold=2,HealthyThreshold=2 >> /dev/null
 
   return 0
}

#===============================================================================
# Deletes the specified Load Balancer. 
# The DNS name associated with a deleted load balancer is no longer usable. 
# The name and associated DNS record of the deleted load balancer no longer 
# exist and traffic sent to any of its IP addresses is no longer delivered to
# your instances.
#
# Globals:
#  None
# Arguments:
# +loadbalancer_nm     -- The load balancer name.
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

   local loadbalancer_nm="${1}"
 
   aws elb delete-load-balancer --load-balancer-name "${loadbalancer_nm}" 

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
# +loadbalancer_nm      -- load balancer name.
# +instance_id          -- the instance ID.
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
   
   local loadbalancer_nm="${1}"
   local instance_id="${2}"
   
   aws elb register-instances-with-load-balancer \
       --load-balancer-name "${loadbalancer_nm}" \
       --instances "${instance_id}" >> /dev/null
   
   return 0
}

#===============================================================================
# Deregisters  the  specified instances from the specified Load Balancer. After 
# the instance is deregistered, it no longer receives traffic from the load 
# balancer.
#
# Globals:
#  None
# Arguments:
# +loadbalancer_nm      -- load balancer name.
# +instance_id          -- the instance ID.
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
   
   local loadbalancer_nm="${1}"
   local instance_id="${2}"
   
   aws elb deregister-instances-from-load-balancer \
       --load-balancer-name "${loadbalancer_nm}" \
       --instances "${instance_id}" >> /dev/null
   
   return 0
}

#===============================================================================
# Checks if an instance is registered with a Load Balancer.
#
# Globals:
#  None
# Arguments:
# +loadbalancer_nm      -- load balancer name.
# +instance_id          -- the instance ID.
# Returns:      
#  The load balancer name if the instance is registered, blanc otherwise.  
#===============================================================================
function check_instance_is_registered_with_loadbalancer()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local loadbalancer_nm="${1}"
   local instance_id="${2}"
   
   local loadbalancer_name
   loadbalancer_name="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?contains(LoadBalancerName, '${loadbalancer_nm}') && contains(Instances[].InstanceId, '${instance_id}')].{LoadBalancerName: LoadBalancerName}" \
       --output text)"                     
            
   echo "${loadbalancer_name}"
   
   return 0
}
