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

   __RESULT=''
   local exit_code=0
   local lbal_nm="${1}"
   local lbal_dns_nm
 
   lbal_dns_nm="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?LoadBalancerName=='${lbal_nm}'].DNSName" \
       --output text)"
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving load balancer DNS name.'
      return "${exit_code}"
   fi                        
            
   __RESULT="${lbal_dns_nm}"
 
   return "${exit_code}"
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
#  the load balancer hosted zone ID in the global _RESULT variable.  
#===============================================================================
function get_loadbalancer_hosted_zone_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   __RESULT=''
   local exit_code=0
   local -r lbal_nm="${1}"
   local lbal_dns_nm_nm=''
 
   lbal_dns_nm_nm="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?LoadBalancerName=='${lbal_nm}'].CanonicalHostedZoneNameID" \
       --output text)"
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving load balancer hosted zone ID.'
      return "${exit_code}"
   fi                        
            
   __RESULT="${lbal_dns_nm_nm}"
 
   return "${exit_code}"
}

#===============================================================================
# Creates a classic load balancer that listens on HTTP 80 port and forwards the 
# requests to the instances on port 8070.  
#
# Globals:
#  None
# Arguments:
# +lbal_nm       -- the load balancer name.
# +lbal_port     -- the load balancer port.
# +instance_port -- the instance port to which the traffic is forwarded.
# +sg_id         -- the load balancer's security group identifier.
# +subnet_id     -- the load balancer's subnet identifier.
# Returns:      
#  None  
#===============================================================================
function create_http_loadbalancer()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   local -r lbal_nm="${1}"
   local -r lbal_port="${2}"
   local -r instance_port="${3}"
   local -r sgp_id="${4}"
   local -r subnet_id="${5}"
 
   aws elb create-load-balancer \
       --load-balancer-name "${lbal_nm}" \
       --security-groups "${sgp_id}" \
       --subnets "${subnet_id}" \
       --region "${DTC_REGION}" \
       --listener LoadBalancerPort="${lbal_port}",InstancePort="${instance_port}",Protocol=http,InstanceProtocol=http > /dev/null
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating load balancer.'
   fi
 
   return "${exit_code}"
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

   local exit_code=0
   local -r lbal_nm="${1}"
 
   aws elb delete-load-balancer --load-balancer-name "${lbal_nm}" 

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting load balancer.'
   fi
 
   return "${exit_code}"
}

#===============================================================================
# Creates an HTTPS listener and attaches it to the specified load balancer.
# The create-load-balancer-listeners command is idempotent.
# Globals:
#  None
# Arguments:
# +lbal_nm       -- the load balancer name.
# +lbal_port     -- the load balancer port.
# +instance_port -- the instance port to which the traffic is forwarded.
# +cert_arn      -- the Amazon Resource Name (ARN) of the certificate.
# Returns:      
#  None  
#===============================================================================
function add_https_listener()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi
   
   local exit_code=0
   local -r lbal_nm="${1}"
   local -r lbal_port="${2}"
   local -r instance_port="${3}"
   local -r cert_arn="${4}"
   
   aws elb create-load-balancer-listeners \
       --load-balancer-name "${lbal_nm}" \
       --listeners Protocol=HTTPS,LoadBalancerPort="${lbal_port}",InstanceProtocol=HTTP,InstancePort="${instance_port}",SSLCertificateId="${cert_arn}" > /dev/null 2>&1
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: adding HTTPS listener.'
   fi
 
   return "${exit_code}"
}

#===============================================================================
# Deletes a listener from the specified load balancer.
# Globals:
#  None
# Arguments:
# +lbal_nm   -- the load balancer name.
# +lbal_port -- the client port number of the listener.
# Returns:      
#  None  
#===============================================================================
function delete_listener()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   local -r lbal_nm="${1}"
   local -r lbal_port="${2}"

   aws elb delete-load-balancer-listeners \
       --load-balancer-name "${lbal_nm}" \
       --load-balancer-ports "${lbal_port}"

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting listener.'
   fi
 
   return "${exit_code}"
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

   local exit_code=0
   local -r lbal_nm="${1}"
 
   aws elb configure-health-check --load-balancer-name "${lbal_nm}" \
       --health-check Target=HTTP:"${WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT}"/elb.htm,Interval=10,Timeout=5,UnhealthyThreshold=2,HealthyThreshold=2 > /dev/null
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: configuring load balancer health check.'
   fi
 
   return "${exit_code}"
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
   
   local exit_code=0
   local -r lbal_nm="${1}"
   local -r instance_id="${2}"
   
   aws elb register-instances-with-load-balancer \
       --load-balancer-name "${lbal_nm}" \
       --instances "${instance_id}" > /dev/null
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: registering instance with load balancer.'
   fi
 
   return "${exit_code}"
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
   
   local exit_code=0
   local -r lbal_nm="${1}"
   local -r instance_id="${2}"
   
   aws elb deregister-instances-from-load-balancer \
       --load-balancer-name "${lbal_nm}" \
       --instances "${instance_id}" > /dev/null
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deregistering instance from load balancer.'
   fi
 
   return "${exit_code}"
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
#  true/false value in the __RESULT global variable.  
#===============================================================================
function check_instance_is_registered_with_loadbalancer()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   __RESULT=''
   local exit_code=0
   local -r lbal_nm="${1}"
   local -r instance_id="${2}"
   local is_registered='false'
   local lbal_name=''
   
   lbal_name="$(aws elb describe-load-balancers \
       --query "LoadBalancerDescriptions[?contains(LoadBalancerName, '${lbal_nm}') && contains(Instances[].InstanceId, '${instance_id}')].{LoadBalancerName: LoadBalancerName}" \
       --output text)" 
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving load balancer.'
      return "${exit_code}"
   fi     
       
   if [[ -n "${lbal_name}" ]]  
   then
      is_registered='true'
   fi                     
            
   __RESULT="${is_registered}"
 
   return "${exit_code}"
}

