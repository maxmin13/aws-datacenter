#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: ec2.sh
#   DESCRIPTION: the script contains functions that use AWS client to make 
#                calls to Amazon Elastic Compute Cloud (Amazon EC2).
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Returns the data center identifier.
#
# Globals:
#  None
# Arguments:
# +dtc_nm -- the data center name.
# Returns:      
#  the data center identifier, or blanc if the data center is not found.  
#===============================================================================
function get_datacenter_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r dtc_nm="${1}"
   local dtc_id=''
 
   dtc_id="$(aws ec2 describe-vpcs \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${dtc_nm}" \
       --query 'Vpcs[*].VpcId' \
       --output text)" 
  
   echo "${dtc_id}"
 
   return 0
}

#===============================================================================
# Creates a data center and waits for it to become available.
#
# Globals:
#  None
# Arguments:
# +dtc_nm -- the data center name.
# Returns:      
#  the data center identifier.  
#===============================================================================
function create_datacenter()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   declare -r dtc_nm="${1}"
   local dtc_id=''
  
   dtc_id="$(aws ec2 create-vpc \
       --cidr-block "${DTC_CDIR}" \
       --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value='${dtc_nm}'}]" \
       --query 'Vpc.VpcId' \
       --output text)"
            
   aws ec2 wait vpc-available \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${dtc_nm}"  
 
   echo "${dtc_id}"
  
   return 0
}

#===============================================================================
# Delete a data center.
#
# Globals:
#  None
# Arguments:
# +dtc_nm -- the data center name.
# Returns:      
#  None.  
#===============================================================================
function delete_datacenter()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   declare -r dtc_id="${1}"
  
   aws ec2 delete-vpc --vpc-id "${dtc_id}"
  
   return 0
}

#===============================================================================
# Returns a JSON string representing the list of the subnet 
# identifiers in a Data Center. Ex:
#
# subnet ids: '[
#     "subnet-016a221d033705c44",
#     "subnet-0861aef5e928a45bd"
# ]'
#
# If the data center is not found or if the data center doesn't have any subnet, the string
# '[]' is returned. 
#
# Globals:
#  None
# Arguments:
# +dtc_id -- the data center identifier.
# Returns:      
#  A JSON string containing the list of subnet identifiers in a data center.
#===============================================================================
function get_subnet_ids()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r dtc_id="${1}"
   local subnet_ids=''
   
   subnet_ids="$(aws ec2 describe-subnets \
       --filters Name=vpc-id,Values="${dtc_id}" \
       --query 'Subnets[*].SubnetId')" 
  
   echo "${subnet_ids}"
 
   return 0
}

#===============================================================================
# Returns the the subnet identifyer.
#
# Globals:
#  None
# Arguments:
# +subnet_nm -- the subnet name.
# Returns:      
#  the subnet identifier, or blanc if it is not found.  
#===============================================================================
function get_subnet_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r subnet_nm="${1}"
   local subnet_id=''
  
   subnet_id="$(aws ec2 describe-subnets \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${subnet_nm}" \
       --query 'Subnets[*].SubnetId' \
       --output text)"
  
   echo "${subnet_id}"
 
   return 0
}

#===============================================================================
# Creates a subnet and waits until it becomes available. the subnet is 
# associated with the route Table.
#
# Globals:
#  None
# Arguments:
# +subnet_nm   -- the subnet name.
# +subnet_cidr -- the subnet CIDR.
# +subnet_az   -- the subnet Availability Zone.
# +dtc_id      -- the data center identifier.
# +rtb_id      -- the route table identifier.
# Returns:      
#  the subnet identifier.  
#===============================================================================
function create_subnet()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r subnet_nm="${1}"
   declare -r subnet_cidr="${2}"
   declare -r subnet_az="${3}"
   declare -r dtc_id="${4}"
   declare -r rtb_id="${5}"
   local subnet_id=''
 
   subnet_id="$(aws ec2 create-subnet \
       --vpc-id "${dtc_id}" \
       --cidr-block "${subnet_cidr}" \
       --availability-zone "${subnet_az}" \
       --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value='${subnet_nm}'}]" \
       --query 'Subnet.SubnetId' \
       --output text)"
 
   aws ec2 wait subnet-available --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${subnet_nm}"
  
  ####################### TODO ASSOCIATE THE SUBNET IN ANOTHER FUNCTION FOR ATOMICITY ############################## 
  
   ## Associate this subnet with our route table 
   aws ec2 associate-route-table --subnet-id "${subnet_id}" --route-table-id "${rtb_id}" 
  
   echo "${subnet_id}"
 
   return 0
}

#===============================================================================
# Deletes a subnet.
#
# Globals:
#  None
# Arguments:
# +subnet_id -- the subnet identifier.
# Returns:      
#  None.  
#===============================================================================
function delete_subnet()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r subnet_id="${1}"
 
   aws ec2 delete-subnet --subnet-id "${subnet_id}"
 
   return 0
}

#============================================================================
# Returns an internet gateway's identifier.
# Globals:
#  None
# Arguments:
# +igw_nm -- the internet gateway name.
# Returns:      
#  the internet gateway identifier, or blanc if it is not found.  
#===============================================================================
function get_internet_gateway_id()
{
   if [[ $# -lt 1 ]]
   then
     echo 'ERROR: missing mandatory arguments.'
     return 128
  fi

   declare -r igw_nm="${1}"
   local igw_id=''
  
   igw_id="$(aws ec2 describe-internet-gateways \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${igw_nm}" \
       --query 'InternetGateways[*].InternetGatewayId' \
       --output text)"
  
   echo "${igw_id}"
 
   return 0
}

#============================================================================
# Returns the current state of the attachment between the gateway and the 
# VPC (data center, virtual private cloud). Present only if a VPC is 
# attached.
#
# Globals:
#  None
# Arguments:
# +igw_nm -- the internet gateway name.
# +dtc_id -- the data center identifier.
# Returns:      
#  the attachment status, or blanc if the data center or the internet gateway  
#  are not found.  
#===============================================================================
function get_internet_gateway_attachment_status()
{
   if [[ $# -lt 2 ]]
   then
     echo 'ERROR: missing mandatory arguments.'
     return 128
  fi

   declare -r igw_nm="${1}"
   declare -r dtc_id="${2}"
   local attachment_status=''
  
   attachment_status="$(aws ec2 describe-internet-gateways \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${igw_nm}" \
       --query "InternetGateways[*].Attachments[?VpcId=='${dtc_id}'].[State]" \
       --output text)"
  
   echo "${attachment_status}"
 
   return 0
}

#===============================================================================
# Creates an internet gateway in detached status.
#
# Globals:
#  None
# Arguments:
# +igw_nm -- the internet gateway name.
# +dtc_id -- the data center ID.
# Returns:      
#  the internet gateway identifier.  
#===============================================================================
function create_internet_gateway()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   declare -r igw_nm="${1}"
   declare -r dtc_id="{2}"
   local igw_id=''
  
   igw_id="$(aws ec2 create-internet-gateway \
       --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value='${igw_nm}'}]" \
       --query 'InternetGateway.InternetGatewayId'\
       --output text)"
  
   echo "${igw_id}"
  
   return 0
}

#===============================================================================
# Deletes an Internet Gateway.
#
# Globals:
#  None
# Arguments:
# +igw_id -- the internet gateway identifier.
# Returns:      
#  None  
#===============================================================================
function delete_internet_gateway()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   declare -r igw_id="${1}"
 
   aws ec2 delete-internet-gateway --internet-gateway-id "${igw_id}"
   
   return 0
}

#===============================================================================
# Attaches an internet gateway to a data center.
#
# Globals:
#  None
# Arguments:
# +igw_id -- the internet gateway identifier.
# +dtc_id -- the data center ID.
# Returns:      
#  None
#===============================================================================
function attach_internet_gateway()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   declare -r igw_id="${1}"
   declare -r dtc_id="${2}"
  
   aws ec2 attach-internet-gateway --vpc-id "${dtc_id}" --internet-gateway-id "${igw_id}"
 
   return 0
}

#===============================================================================
# Returns the the route table identifyer.
#
# Globals:
#  None
# Arguments:
# +rtb_nm -- the route table name.
# Returns:      
#  the route table identifier, or blanc if it is not found.  
#===============================================================================
function get_route_table_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r rtb_nm="${1}"
   local rtb_id=''
  
   rtb_id="$(aws ec2 describe-route-tables \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${rtb_nm}" \
       --query 'RouteTables[*].RouteTableId' \
       --output text)"
  
   echo "${rtb_id}"
 
   return 0
}

#===============================================================================
# Creates a custom route Table.
#
# Globals:
#  None
# Arguments:
# +rtb_nm -- the route table name.
# +dtc_id -- the data center identifier.

# Returns:      
#  the route table identifier, or blanc if it is not found.  
#===============================================================================
function create_route_table()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r rtb_nm="${1}"
   declare -r dtc_id="${2}"
   local rtb_id=''
  
   rtb_id="$(aws ec2 create-route-table \
       --vpc-id "${dtc_id}" \
       --query 'RouteTable.RouteTableId' \
       --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value='${rtb_nm}'}]" \
       --output text)"
 
   echo "${rtb_id}"
 
   return 0
}

#===============================================================================
# Delete a route Table.
#
# Globals:
#  None
# Arguments:
# +rtb_id -- the route table identifier.

# Returns:      
#  None  
#===============================================================================
function delete_route_table()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r rtb_id="${1}"
  
   aws ec2 delete-route-table --route-table-id "${rtb_id}"
 
   return 0
}

#===============================================================================
# Creates a route in a route Table: the incoming traffic with destination the
# specified cidr block is routed to the target.
#
# Globals:
#  None
# Arguments:
# +rtb_id           -- the route table identifier.
# +target_id        -- the target identifier, for ex: an Internet Gateway.
# +destination_cidr -- the CIDR address block used to match the destination
#                      of the incoming traffic.
# Returns:      
#  None
#===============================================================================
function set_route()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r rtb_id="${1}"
   declare -r target_id="${2}"
   declare -r destination_cidr="${3}"
   
   aws ec2 create-route --route-table-id "${rtb_id}" \
       --destination-cidr-block "${destination_cidr}" \
       --gateway-id "${target_id}" 

   return 0
}

#===============================================================================
# Returns the the security group identifyer.
#
# Globals:
#  None
# Arguments:
# +sgp_nm -- the security group name.
# Returns:      
#  the security group identifier, or blanc if it is not found.  
#===============================================================================
function get_security_group_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r sgp_nm="${1}"
   local sgp_id=''
  
   sgp_id="$(aws ec2 describe-security-groups \
         --filters Name=tag-key,Values='Name' \
         --filters Name=tag-value,Values="${sgp_nm}" \
         --query 'SecurityGroups[*].GroupId' \
         --output text)"
  
   echo "${sgp_id}"
 
   return 0
}

#===============================================================================
# Creates a security group.
#
# Globals:
#  None
# Arguments:
# +dtc_id        -- the data center identifier.
# +sgp_nm         -- the security group name.
# +sgp_desc       -- the security group description.
# Returns:      
#  the security group identifier.  
#===============================================================================
function create_security_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r dtc_id="${1}" 
   declare -r sgp_nm="${2}"
   declare -r sgp_desc="${3}"  
   local sgp_id=''
   
   sgp_id="$(aws ec2 create-security-group \
        --group-name "${sgp_nm}" \
        --description "${sgp_desc}" \
        --vpc-id "${dtc_id}" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value='${sgp_nm}'}]" \
        --query 'GroupId' \
        --output text)"

   echo "${sgp_id}"

   return 0
}

#===============================================================================
# Deletes a security group.
#
# Globals:
#  None
# Arguments:
# +sgp_id -- the security group identifier.
# Returns:      
#  None    
#===============================================================================
function delete_security_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r sgp_id="${1}"
   local exit_code=0
   
   set +e
   aws ec2 delete-security-group --group-id "${sgp_id}" 
   exit_code=$?
   set -e
   
   return "${exit_code}"
}

#===============================================================================
# Allow access to the traffic incoming from a CIDR block.  
#
# Globals:
#  None
# Arguments:
# +sgp_id    -- the security group identifier.
# +port      -- the TCP port
# +protocol  -- the IP protocol name (tcp , udp , icmp , icmpv6), default is tcp. 
# +from_cidr -- the CIDR block representing the origin of the traffic.
# Returns:      
#  None
#===============================================================================
function allow_access_from_cidr()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r sgp_id="${1}"
   declare -r port="${2}"
   declare -r protocol="${3}"
   declare -r from_cidr="${4}"
   
   aws ec2 authorize-security-group-ingress \
       --group-id "${sgp_id}" \
       --protocol "${protocol}" \
       --port "${port}" \
       --cidr "${from_cidr}" 
 
   return 0
}

#===============================================================================
# Allows access to the traffic incoming from another security group.
#
# Globals:
#  None
# Arguments:
# +sgp_id      -- the security group identifier.
# +port        -- the TCP port.
# +protocol    -- the IP protocol name (tcp , udp , icmp , icmpv6), default is 
#                 tcp.
# +from_sgp_id -- the security group identifier representing the origin of the
#                 traffic. 
# Returns:      
#  None
#===============================================================================
function allow_access_from_security_group()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r sgp_id="${1}"
   declare -r port="${2}"
   declare -r protocol="${3}"
   declare -r from_sgp_id="${4}" 

   aws ec2 authorize-security-group-ingress \
       --group-id "${sgp_id}" \
       --protocol "${protocol}" \
       --port "${port}" \
       --source-group "${from_sgp_id}" 

   return 0
}

#===============================================================================
# Revokes access to the traffic incoming from another security group.  
#
# Globals:
#  None
# Arguments:
# +sgp_id   -- the security group identifier.
# +port     -- the TCP port.
# +protocol -- the IP protocol name (tcp , udp , icmp , icmpv6), default is 
#                 tcp. 
# +from_sgp_id -- the security group identifier representing the origin of the
#                 traffic. 
# Returns:      
#  None
#===============================================================================
function revoke_access_from_security_group()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r sgp_id="${1}"
   declare -r port="${2}"
   declare -r protocol="${3}"
   declare -r from_sgp_id="${4}"   

   aws ec2 revoke-security-group-ingress \
       --group-id "${sgp_id}" \
       --protocol "${protocol}" \
       --port "${port}" \
       --source-group "${from_sgp_id}" 

   return 0
}

#===============================================================================
# Revokes access to the traffic incoming from a specific CIDR block.  
#
# Globals:
#  None
# Arguments:
# +sgp_id    -- the security group identifier.
# +port      -- the TCP port
# +protocol  -- the IP protocol name (tcp , udp , icmp , icmpv6), default is tcp. 
# +from_cidr -- the CIDR block representing the origin of the traffic.
# Returns:      
#  None
#===============================================================================
function revoke_access_from_cidr()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r sgp_id="${1}"
   declare -r port="${2}"
   declare -r protocol="${3}"
   declare -r from_cidr="${4}"
        
   aws ec2 revoke-security-group-ingress \
       --group-id "${sgp_id}" \
       --protocol "${protocol}" \
       --port "${port}" \
       --cidr "${from_cidr}" 

   return 0
}

#===============================================================================
# Checks if a access on a TCP port is granted to traffic incoming from a 
# specific security group. 
#
# Globals:
#  None
# Arguments:
# +sgp_id      -- the security group identifier.
# +port        -- the TCP port.
# +protocol    -- the IP protocol name (tcp , udp , icmp , icmpv6), default is 
#                 tcp. 
# +from_sgp_id -- the security group identifier representing the origin of the
#                 traffic. 
# Returns:      
#  the group identifier if the access is granted, blanc otherwise.
#===============================================================================
function check_access_from_security_group_is_granted()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r sgp_id="${1}"
   declare -r port="${2}"
   declare -r protocol="${3}"
   declare -r from_sgp_id="${4}"  
   local id=''

   id="$(aws ec2 describe-security-groups \
       --group-ids="${sgp_id}" \
       --filters Name=ip-permission.to-port,Values="${port}" \
       --query "SecurityGroups[? IpPermissions[? IpProtocol == '${protocol}' && UserIdGroupPairs[? GroupId == '${from_sgp_id}']]].GroupId" \
       --output text)"                     
            
   echo "${id}"
   
   return 0
}

#===============================================================================
# Checks if a access on a TCP port is granted to traffic incoming from a 
# specific CIDR block. 
#
# Globals:
#  None
# Arguments:
# +sgp_id    -- the security group identifier.
# +port      -- the TCP port
# +protocol  -- the IP protocol name (tcp , udp , icmp , icmpv6), default is tcp. 
# +from_cidr -- the CIDR block representing the origin of the traffic.
# Returns:      
#  the group identifier if the access is granted, blanc otherwise.
#===============================================================================
function check_access_from_cidr_is_granted()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r sgp_id="${1}"
   declare -r port="${2}"
   declare -r protocol="${3}"
   declare -r from_cidr="${4}"
   local id=''
     
   id="$(aws ec2 describe-security-groups \
       --group-ids="${sgp_id}" \
       --filters Name=ip-permission.to-port,Values="${port}" \
       --query "SecurityGroups[? IpPermissions[? IpProtocol == '${protocol}' && IpRanges[? CidrIp == '${from_cidr}']]].GroupId" \
       --output text)"           
         
   echo "${id}"
   
   return 0
}

#===============================================================================
# Returns an instance's status.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# Returns:      
#  the status of the instance, or blanc if the instance is not found.  
#===============================================================================
function get_instance_state()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r instance_nm="${1}"
   local instance_st=''
  
   instance_st="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${instance_nm}" \
       --query 'Reservations[*].Instances[*].State.Name' \
       --output text)"

   echo "${instance_st}"
 
   return 0
}

#===============================================================================
# Returns the public IP address associated to an instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# Returns:      
#  the instance public address, or blanc if the instance is not found.  
#===============================================================================
function get_public_ip_address_associated_with_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r instance_nm="${1}"
   local instance_ip=''
  
   instance_ip="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${instance_nm}" \
       --query 'Reservations[*].Instances[*].PublicIpAddress' \
       --output text )"

   echo "${instance_ip}"
 
   return 0
}

#===============================================================================
# Returns the private IP address associated to an instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# Returns:      
#  the instance private address, or blanc if the instance is not found.  
#===============================================================================
function get_private_ip_address_associated_with_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r instance_nm="${1}"
   local instance_ip=''
  
   instance_ip="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${instance_nm}" \
       --query 'Reservations[*].Instances[*].PrivateIpAddress' \
       --output text )"

   echo "${instance_ip}"
 
   return 0
}

#===============================================================================
# Returns the instance identifier.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# Returns:      
#  the instance identifier, or blanc if the instance is not found.  
#===============================================================================
function get_instance_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   exit_code=0
   declare -r instance_nm="${1}"
   local instance_id=''

   instance_id="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${instance_nm}" \
       --query 'Reservations[*].Instances[*].InstanceId' \
       --output text)"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting instance ID.'
      return "${exit_code}"
   fi 

   __RESULT="${instance_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Runs an instance and associates a public IP address to it.
# Globals:
#  None
# Arguments:
# +instance_nm     -- name assigned to the instance.
# +sgp_id          -- security group identifier.
# +subnet_id       -- subnet identifier.
# +private_ip      -- private IP address assigned to the instance.
# +image_id        -- identifier of the image from which the instance is
#                     derived.
# +cloud_init_file -- Cloud Init configuration file.
# Returns:      
#  none.   
#===============================================================================
function run_instance()
{
   if [[ $# -lt 6 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r instance_nm="${1}"
   declare -r sgp_id="${2}"
   declare -r subnet_id="${3}"
   declare -r private_ip="${4}"
   declare -r image_id="${5}"
   declare -r cloud_init_file="${6}"
   local exit_code=0
   local instance_id=''
     
   instance_id="$(aws ec2 run-instances \
       --image-id "${image_id}" \
       --security-group-ids "${sgp_id}" \
       --instance-type 't2.micro' \
       --placement "AvailabilityZone=${DTC_DEPLOY_ZONE_1},Tenancy=default" \
       --subnet-id "${subnet_id}" \
       --private-ip-address "${private_ip}" \
       --associate-public-ip-address \
       --block-device-mapping 'DeviceName=/dev/xvda,Ebs={DeleteOnTermination=true,VolumeSize=10}' \
       --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${instance_nm}}]" \
       --user-data file://"${cloud_init_file}" \
       --output text \
       --query 'Instances[*].InstanceId')"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: running Admin instance.'
      return "${exit_code}"
   fi    
   
   aws ec2 wait instance-status-ok --instance-ids "${instance_id}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: waiting for Admin instance.'
   fi   
   
   return "${exit_code}"
}

#===============================================================================
# Stops the instance and waits for it to stop.
#
# Globals:
#  None
# Arguments:
# +instance_id -- the instance identifier.
# Returns:      
#  None
#===============================================================================
function stop_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r instance_id="${1}"

   aws ec2 stop-instances --instance-ids "${instance_id}" 
   aws ec2 wait instance-stopped --instance-ids "${instance_id}" 

   return 0
}

#===============================================================================
# Deletes the Instance. 
# Terminated Instances remain visible after termination for approximately one 
# hour. Any attached EBS volumes with the DeleteOnTermination block device 
# mapping parameter set to true are automatically deleted.
#
# Globals:
#  None
# Arguments:
# +instance_id     -- the instance identifier.
# +wait_terminated -- if passed and equal to 'and_wait, the function wait until
#                     the instance is in termitanted state.
# Returns:      
#  None
#===============================================================================
function delete_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r instance_id="${1}"
   local wait_terminated=''
   
   if [[ $# -eq 2 ]]
   then
      wait_terminated="${2}"
   fi

   aws ec2 terminate-instances --instance-ids "${instance_id}" 
   
   if [[ 'and_wait' == "${wait_terminated}" ]]
   then
      aws ec2 wait instance-terminated --instance-ids "${instance_id}"
   fi
   
   return 0
}

#===============================================================================
# Checks if the specified EC2 instance has an IAM instance profile associated.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +instance_id -- the instance ID.
# +profile_nm  -- the IAM instance profile name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function check_instance_has_instance_profile_associated()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   declare -r instance_nm="${1}"
   declare -r profile_nm="${2}"
   local instance_id=''
   local profile_id=''
   local association_id=''
   local associated='false'
   
   __get_association_id "${instance_nm}" "${profile_nm}"

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the association ID.' 
      return "${exit_code}"
   fi
   
   association_id="${__RESULT}"
   __RESULT=''
   
   if [[ -n "${association_id}" ]]
   then
      associated='true' 
   fi
       
   __RESULT="${associated}"

   return "${exit_code}" 
}

#===============================================================================
# Associates the specified instance profile to an EC2 instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +profile_nm  -- the IAM instance profile name.
# Returns:      
#  none.  
#===============================================================================
function associate_instance_profile_to_instance()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   declare -r instance_nm="${1}"
   declare -r profile_nm="${2}"
   local instance_id=''
   local profile_id=''
   
   get_instance_id "${instance_nm}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance ID.' 
      return "${exit_code}"
   fi
   
   instance_id="${__RESULT}"
   __RESULT=''
   
   if [[ -z "${instance_id}" ]]
   then
      echo 'ERROR: EC2 instance not found.'
      return 1
   fi
   
   get_instance_profile_id "${profile_nm}" 
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance profile ID.' 
      return "${exit_code}"
   fi
   
   profile_id="${__RESULT}"
   __RESULT=''
   
   if [[ -z "${profile_id}" ]]
   then
      echo 'ERROR: instance profile not found.'
      return 1
   fi
   
   aws ec2 associate-iam-instance-profile --iam-instance-profile Name="${profile_nm}" \
       --instance-id "${instance_id}"    
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: associating instance profile to EC2 instance.'
   fi
   
   return "${exit_code}" 
}

#===============================================================================
# Disassociate the specified instance profile to an EC2 instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +profile_nm  -- the IAM instance profile name.
# Returns:      
#  none.  
#===============================================================================
function disassociate_instance_profile_from_instance()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   declare -r instance_nm="${1}"
   declare -r profile_nm="${2}"
   local instance_id=''
   local profile_id=''
   local association_id=''
   
   __get_association_id "${instance_nm}" "${profile_nm}"
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the association ID.' 
      return "${exit_code}"
   fi
   
   association_id="${__RESULT}"
   __RESULT=''
   
   if [[ -z "${association_id}" ]]
   then
      echo 'ERROR: association ID not found.'
      return 1
   fi
   
   aws ec2 disassociate-iam-instance-profile --association-id "${association_id}"  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: disassociating instance profile to EC2 instance.'
   fi
   
   return "${exit_code}" 
}

#===============================================================================
# Returns the association ID of an association in state 'associated' between
# an instance profile and an EC2 instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +profile_nm  -- the IAM instance profile name.
# Returns:      
#  the association ID in the __RESULT global variable.  
#===============================================================================
function __get_association_id()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   declare -r instance_nm="${1}"
   declare -r profile_nm="${2}"
   local instance_id=''
   local profile_id=''
   local association_id=''
   
   get_instance_id "${instance_nm}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance ID.' 
      return "${exit_code}"
   fi
   
   instance_id="${__RESULT}"
   __RESULT=''
   
   if [[ -z "${instance_id}" ]]
   then
      echo 'ERROR: EC2 instance not found.'
      return 1
   fi
   
   get_instance_profile_id "${profile_nm}" 
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance profile ID.' 
      return "${exit_code}"
   fi
   
   profile_id="${__RESULT}"
   __RESULT=''

   if [[ -z "${profile_id}" ]]
   then
      echo 'ERROR: instance profile not found.'
      return 1
   fi
   
   association_id="$(aws ec2 describe-iam-instance-profile-associations \
       --query "IamInstanceProfileAssociations[? InstanceId == '${instance_id}' && IamInstanceProfile.Id == '${profile_id}' ].AssociationId" \
       --output text)"
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the association ID.' 
      return "${exit_code}"
   fi
   
   if [[ -z "${association_id}" ]]
   then
      echo 'Association ID not found.'
   fi
   
   __RESULT="${association_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates an image from an Amazon EBS-backed instance and waits until the image
# is ready.
# Globals:
#  None
# Arguments:
# +instance_id -- the instance identifier.
# +img_nm      -- the image name.
# +img_desc    -- the image description.
# Returns:      
#  none.    
#===============================================================================
function create_image()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r instance_id="${1}"
   declare -r img_nm="${2}"
   declare -r img_desc="${3}"
   local img_id=''
   local exit_code=0

   img_id="$(aws ec2 create-image \
        --instance-id "${instance_id}" \
        --name "${img_nm}" \
        --description "${img_desc}" \
        --query 'ImageId' \
        --output text)" 
  
   # If the caller sets 'set +e' to analyze the return code, this functions
   # doesn't exit immediately with error, so it is necessary to get the error
   # code in any case and return it.
   exit_code=$?    
   
   if [[ 0 -eq "${exit_code}" ]]    
   then
      aws ec2 wait image-available --image-ids "${img_id}"
   fi
   
   return "${exit_code}" 
}

#===============================================================================
# Returns an images's identifier.
# Globals:
#  None
# Arguments:
# +img_nm -- the image name.
# Returns:      
#  the Image identifier.
#===============================================================================
function get_image_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r img_nm="${1}"
   local img_id=''

   img_id="$(aws ec2 describe-images \
        --filters Name=name,Values="${img_nm}" \
        --query 'Images[*].ImageId' \
        --output text)"
  
   echo "${img_id}"
 
   return 0
}

#===============================================================================
# Returns an images's state.
# Globals:
#  None
# Arguments:
# +img_nm -- the image name.
# Returns:      
#  the Image state.
#===============================================================================
function get_image_state()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r img_nm="${1}"
   local img_state=''

   img_state="$(aws ec2 describe-images \
        --filters Name=name,Values="${img_nm}" \
        --query 'Images[*].State' \
        --output text)"
  
   echo "${img_state}"
 
   return 0
}

#===============================================================================
# Returns the list of an image's snapshot identifiers as a string of IDs
# separated by space. 
#
# Globals:
#  None
# Arguments:
# +img_nm -- the image name.
# Returns:      
#  the list of Image Snapshot identifiers, or blanc if no Snapshot is found.  
#===============================================================================
function get_image_snapshot_ids()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r img_nm="${1}"

   # AWS CLI provides built-in JSON-based output filtering capabilities with the --query option,
   # a JMESPATH expression is used as a filter. 
   local img_snapshot_ids=''

   img_snapshot_ids="$(aws ec2 describe-images \
       --filters Name=name,Values="${img_nm}" \
       --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' \
       --output text)"
  
   echo "${img_snapshot_ids}"
 
   return 0
}

#===============================================================================
# Deletes (deregisters) the specified Image.
#
# Globals:
#  None
# Arguments:
# +img_id  -- the Image identifier.
# Returns:      
#  None
#========================================================
function delete_image()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r img_id="${1}"

   aws ec2 deregister-image --image-id "${img_id}"

   return 0
}

#===============================================================================
# Deletes a Snapshot by identifier. the Image must be 
# deregisterd first.
#
# Globals:
#  None
# Arguments:
# +img_snapshot_id -- the Image Snapshot identifier.
# Returns:      
#  None
#========================================================
function delete_image_snapshot()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r img_snapshot_id="${1}"

   aws ec2 delete-snapshot --snapshot-id "${img_snapshot_id}" 

   return 0
}

#===============================================================================
# Returns the public IP address allocation identifier. If the address is not 
# allocated with your account, a blanc string is returned.
#
# Globals:
#  None
# Arguments:
# +eip -- the Elastic IP Public address.
# Returns:      
#  the allocation identifier, or blanc if the address is not allocate with your
#  account.  
#===============================================================================
function get_allocation_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r eip="${1}"
   local allocation_id=''
          
   allocation_id="$(aws ec2 describe-addresses \
       --filter Name=public-ip,Values="${eip}" \
       --query 'Addresses[*].AllocationId' \
       --output text)"

   echo "${allocation_id}"
 
   return 0
}

#===============================================================================
# Returns a list of allocation identifiers associated your account.
# The list is a string where each identifier is separated by a space.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  A list of allocation identifiers, or blanc if no address is allocated with 
#  your account.  
#===============================================================================
function get_all_allocation_ids()
{
   local allocation_ids=''
          
   allocation_ids="$(aws ec2 describe-addresses \
       --query 'Addresses[*].AllocationId' \
       --output text)"

   echo "${allocation_ids}"
 
   return 0
}

#===============================================================================
# Returns an IP Address allocated to your AWS account not associated with an 
# Instance. If no Address if found, an empty string is returned.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  An unused public IP Address in your account, or blanc if the Address is not 
#  found.  
#===============================================================================
function get_public_ip_address_unused()
{
   local eip=''
   local eip_list=''
   
   eip_list="$(aws ec2 describe-addresses \
       --query 'Addresses[?InstanceId == null].PublicIp' \
       --output text)"
            
   if [[ -n "${eip_list}" ]]; then
       #Getting the first
       eip="$(echo "${eip_list}" | awk '{print $1}')"
   fi
            
   echo "${eip}"
 
   return 0
}

#===============================================================================
# Allocates an Elastic IP address to your AWS account. After you allocate the 
# Elastic IP address you can associate it with an instance or network interface.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  the IP address allocated to your account.  
#===============================================================================
function allocate_public_ip_address()
{
   local eip=''
  
   eip="$(aws ec2 allocate-address \
       --query 'PublicIp' \
       --output text)"

   echo "${eip}"
 
   return 0
}

#===============================================================================
# Releases an Elastic IP address allocated with your account.
# Releasing an Elastic IP address automatically disassociates it from the 
# instance. Be sure to update your DNS records and any servers or devices that 
# communicate with the address.
#
# Globals:
#  None
# Arguments:
# +allocation_id -- allocation identifier.
# Returns:      
#  None 
#===============================================================================
function release_public_ip_address()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r allocation_id="${1}"

   aws ec2 release-address --allocation-id "${allocation_id}" 

   return 0
}

#===============================================================================
# Releases a list of Elastic IP addresses allocated with your account.
# Releasing an Elastic IP address automatically disassociates it from the 
# instance. Be sure to update your DNS records and any servers or devices that 
# communicate with the address.
#
# Globals:
#  None
# Arguments:
#  +allocation_ids -- the list of allocation identifiers.
# Returns:      
#  None 
#===============================================================================
function release_all_public_ip_addresses()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   declare -r allocation_ids="${1}"
          
   for id in ${allocation_ids}
   do
      aws ec2 release-address --allocation-id "${id}" 
   done

   return 0
}

#===============================================================================
# Associates an Elastic IP address with an instance.  
# Before you can use an Elastic IP address, you must allocate it to your 
# account.
#
# Globals:
#  None
# Arguments:
# +eip         -- the public IP address.
# +instance_id -- the instance identifier.
# Returns:      
#  None 
#===============================================================================
function associate_public_ip_address_to_instance()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   declare -r eip="${1}"
   declare -r instance_id="${2}"
  
   aws ec2 associate-address \
       --instance-id "${instance_id}" \
       --public-ip "${eip}" 

   return 0
}
