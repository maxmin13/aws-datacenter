#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: ec2.sh
#   DESCRIPTION: The script contains functions that use AWS client to make 
#                calls to Amazon Elastic Compute Cloud (Amazon EC2).
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Returns the VPC identifier by name.
#
# Globals:
#  None
# Arguments:
# +vpc_nm     -- The VPC name.
# Returns:      
#  The VPC identifier, or blanc if the VPC is not found.  
#===============================================================================
function get_vpc_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local vpc_nm="${1}"
   local vpc_id
 
   vpc_id="$(aws ec2 describe-vpcs \
                        --filters Name=tag-key,Values='Name' \
                        --filters Name=tag-value,Values="${vpc_nm}" \
                        --query 'Vpcs[*].VpcId' \
                        --output text)" 
  
   echo "${vpc_id}"
 
   return 0
}

#===============================================================================
# Creates a VPC and waits for it to become available.
#
# Globals:
#  None
# Arguments:
# +vpc_nm     -- The VPC name.
# Returns:      
#  The VPC identifier.  
#===============================================================================
function create_vpc()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
  
   local vpc_nm="${1}"
   local vpc_id
  
   vpc_id="$(aws ec2 create-vpc \
                           --cidr-block "${VPC_CDIR}" \
                           --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value='${vpc_nm}'}]" \
                           --query 'Vpc.VpcId' \
                           --output text)"
                           
   aws ec2 wait vpc-available \
                           --filters Name=tag-key,Values='Name' \
                           --filters Name=tag-value,Values="${vpc_nm}"  
 
   echo "${vpc_id}"
  
   return 0
}

#===============================================================================
# Delete a VPC.
#
# Globals:
#  None
# Arguments:
# +vpc_nm     -- The VPC name.
# Returns:      
#  None.  
#===============================================================================
function delete_vpc()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
  
   local vpc_id="${1}"
  
   aws ec2 delete-vpc --vpc-id "${vpc_id}"
  
   return 0
}

#===============================================================================
# Returns a JSON string representing the list of the subnet 
# identifiers in a VPC. Ex:
#
# Subnet ids: '[
#     "subnet-016a221d033705c44",
#     "subnet-0861aef5e928a45bd"
# ]'
#
# If the VPC is not found or if the VPC doesn't have any subnet, the string
# '[]' is returned. 
#
# Globals:
#  None
# Arguments:
# +vpc_id     -- The VPC identifier.
# Returns:      
#  A JSON string containing the list of subnet identifiers in a VPC.
#===============================================================================
function get_subnet_ids()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local vpc_id="${1}"
   local subnet_ids
   
   subnet_ids="$(aws ec2 describe-subnets \
                        --filters Name=vpc-id,Values="${vpc_id}" \
                        --query 'Subnets[*].SubnetId')" 
  
   echo "${subnet_ids}"
 
   return 0
}

#===============================================================================
# Returns the the Subnet identifyer by name.
#
# Globals:
#  None
# Arguments:
# +subnet_nm     -- The Subnet name.
# Returns:      
#  The Subnet identifier, or blanc if it is not found.  
#===============================================================================
function get_subnet_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local subnet_nm="${1}"
   local subnet_id
  
   subnet_id="$(aws ec2 describe-subnets \
	                --filters Name=tag-key,Values='Name' \
                        --filters Name=tag-value,Values="${subnet_nm}" \
	                --query 'Subnets[*].SubnetId' \
	                --output text)"
  
   echo "${subnet_id}"
 
   return 0
}

#===============================================================================
# Creates a Subnet and waits until it becomes available. The subnet is 
# associated with the Route Table.
#
# Globals:
#  None
# Arguments:
# +subnet_nm       -- The Subnet name.
# +subnet_cidr     -- The Subnet CIDR.
# +subnet_az       -- The Subnet Availability Zone.
# +vpc_id          -- The VPC identifier.
# +rtb_id          -- The Route Table identifier.
# Returns:      
#  The Subnet identifier.  
#===============================================================================
function create_subnet()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local subnet_nm="${1}"
   local subnet_cidr="${2}"
   local subnet_az="${3}"
   local vpc_id="${4}"
   local rtb_id="${5}"
   local subnet_id
 
   subnet_id="$(aws ec2 create-subnet \
                          --vpc-id "${vpc_id}" \
                          --cidr-block "${subnet_cidr}" \
                          --availability-zone "${subnet_az}" \
                          --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value='${subnet_nm}'}]" \
                          --query 'Subnet.SubnetId' \
                          --output text)"
 
   aws ec2 wait subnet-available --filters Name=tag-key,Values=Name\
                                   --filters Name=tag-value,Values="${subnet_nm}"
  
  ####################### TODO ASSOCIATE THE SUBNET IN ANOTHER FUNCTION FOR ATOMICITY ############################## 
  
   ## Associate this subnet with our route table 
   aws ec2 associate-route-table --subnet-id "${subnet_id}" --route-table-id "${rtb_id}" >> /dev/null
  
   echo "${subnet_id}"
 
   return 0
}

#===============================================================================
# Deletes a Subnet.
#
# Globals:
#  None
# Arguments:
# +subnet_id       -- The Subnet identifier.
# Returns:      
#  None.  
#===============================================================================
function delete_subnet()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local subnet_id="${1}"
 
   aws ec2 delete-subnet --subnet-id "${subnet_id}"
 
   return 0
}

#============================================================================
# Returns the the Internet Gateway identifyer by name.
#
# Globals:
#  None
# Arguments:
# +igw_nm     -- The Internet Gateway name.
# Returns:      
#  The Internet Gateway identifier, or blanc if it is not found.  
#===============================================================================
function get_internet_gateway_id()
{
   if [[ $# -lt 1 ]]
   then
     echo 'Error: Missing mandatory arguments'
     exit 1
  fi

   local igw_nm="${1}"
   local igw_id
  
   igw_id="$(aws ec2 describe-internet-gateways \
	                --filters Name=tag-key,Values='Name' \
                        --filters Name=tag-value,Values="${igw_nm}" \
	                --query 'InternetGateways[*].InternetGatewayId' \
	                --output text)"
  
   echo "${igw_id}"
 
   return 0
}

#============================================================================
# Returns the status of the attachement of the Internet Gateway to the VPD,
# eg. 'available', 
#
# Globals:
#  None
# Arguments:
# +igw_nm     -- The Internet Gateway name.
# +vpc_id     -- The VPC identifier.
# Returns:      
#  The attachment status, or blanc if the VPC or the Internet Gateway are not 
#  found.  
#===============================================================================
function get_internet_gateway_attachment_status()
{
   if [[ $# -lt 2 ]]
   then
     echo 'Error: Missing mandatory arguments'
     exit 1
  fi

   local igw_nm="${1}"
   local vpc_id="${2}"
   local attachment_status
  
   attachment_status="$(aws ec2 describe-internet-gateways \
	                --filters Name=tag-key,Values='Name' \
                        --filters Name=tag-value,Values="${igw_nm}" \
	                --query "InternetGateways[*].Attachments[?VpcId=='${vpc_id}'].[State]" \
                        --output text)"
  
   echo "${attachment_status}"
 
   return 0
}

#===============================================================================
# Creates an Internet Gateway in detached status.
#
# Globals:
#  None
# Arguments:
# +igw_nm     -- The Internet Gateway name.
# +vpc_id     -- The VPC id.
# Returns:      
#  The Internet Gateway identifier.  
#===============================================================================
function create_internet_gateway()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
  
   local igw_nm="${1}"
   local vpc_id="{2}"
   local igw_id
  
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
# +igw_id     -- The Internet Gateway identifier.
# Returns:      
#  None  
#===============================================================================
function delete_internet_gateway()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
  
   local igw_id="${1}"
 
   aws ec2 delete-internet-gateway --internet-gateway-id "${igw_id}"
   
   return 0
}

#===============================================================================
# Attaches an Internet Gateway to a VPC.
#
# Globals:
#  None
# Arguments:
# +igw_id     -- The Internet Gateway identifier.
# +vpc_id     -- The VPC id.
# Returns:      
#  None
#===============================================================================
function attach_internet_gateway()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
  
   local igw_id="${1}"
   local vpc_id="${2}"
  
   aws ec2 attach-internet-gateway --vpc-id "${vpc_id}" --internet-gateway-id "${igw_id}"
 
   return 0
}

#===============================================================================
# Returns the the Route Table identifyer by name.
#
# Globals:
#  None
# Arguments:
# +rtb_nm     -- The Route Table name.
# Returns:      
#  The Route Table identifier, or blanc if it is not found.  
#===============================================================================
function get_route_table_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local rtb_nm="${1}"
   local rtb_id
  
   rtb_id="$(aws ec2 describe-route-tables \
	                --filters Name=tag-key,Values='Name' \
                        --filters Name=tag-value,Values="${rtb_nm}" \
	                --query 'RouteTables[*].RouteTableId' \
	                --output text)"
  
   echo "${rtb_id}"
 
   return 0
}

#===============================================================================
# Creates a custom Route Table.
#
# Globals:
#  None
# Arguments:
# +rtb_nm     -- The Route Table name.
# +vpc_id     -- The VPC identifier.

# Returns:      
#  The Route Table identifier, or blanc if it is not found.  
#===============================================================================
function create_route_table()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local rtb_nm="${1}"
   local vpc_id="${2}"
   local rtb_id
  
   rtb_id="$(aws ec2 create-route-table \
                          --vpc-id "${vpc_id}" \
                          --query 'RouteTable.RouteTableId' \
                          --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value='${rtb_nm}'}]" \
                          --output text)"
 
   echo "${rtb_id}"
 
   return 0
}

#===============================================================================
# Delete a Route Table.
#
# Globals:
#  None
# Arguments:
# +rtb_id     -- The route table identifier.

# Returns:      
#  None  
#===============================================================================
function delete_route_table()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local rtb_id="${1}"
  
   aws ec2 delete-route-table --route-table-id "${rtb_id}"
 
   return 0
}

#===============================================================================
# Creates a route in a Route Table: the incoming traffic with destination the
# specified cidr block is routed to the target.
#
# Globals:
#  None
# Arguments:
# +rtb_id               -- The Route Table identifier.
# +target_id            -- The target identifier, for ex: an Internet Gateway.
# +destination_cidr     -- The CIDR address block used to match the destination
#                          of the incoming traffic.
# Returns:      
#  None
#===============================================================================
function set_route()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local rtb_id="${1}"
   local target_id="${2}"
   local destination_cidr="${3}"
   
   aws ec2 create-route --route-table-id "${rtb_id}" \
                        --destination-cidr-block "${destination_cidr}" \
                        --gateway-id "${target_id}" >> /dev/null

   return 0
}

#===============================================================================
# Returns the the Security Group identifyer by name.
#
# Globals:
#  None
# Arguments:
# +sg_nm         -- The Security Group name.
# Returns:      
#  The Security Group identifier, or blanc if it is not found.  
#===============================================================================
function get_security_group_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local sg_nm="${1}"
   local sg_id
  
   sg_id="$(aws ec2 describe-security-groups \
                        --filters Name=tag-key,Values='Name' \
                        --filters Name=tag-value,Values="${sg_nm}" \
                        --query 'SecurityGroups[*].GroupId' \
                        --output text)"
  
   echo "${sg_id}"
 
   return 0
}

#===============================================================================
# Creates a Security Group.
#
# Globals:
#  None
# Arguments:
# +vpc_id        -- The VPC identifier.
# +sg_nm         -- The Security Group name.
# +sg_desc       -- The Security Group description.
# Returns:      
#  The Security Group identifier.  
#===============================================================================
function create_security_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local vpc_id="${1}" 
   local sg_nm="${2}"
   local sg_desc="${3}"  
   local sg_id
   
   sg_id="$(aws ec2 create-security-group \
                        --group-name "${sg_nm}" \
                        --description "${sg_desc}" \
                        --vpc-id "${vpc_id}" \
                        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value='${sg_nm}'}]" \
                        --query 'GroupId' \
                        --output text)"

   echo "${sg_id}"

   return 0
}

#===============================================================================
# Deletes a Security Group.
#
# Globals:
#  None
# Arguments:
# +sg_id     -- The Security Group identifier.
# Returns:      
#  None    
#===============================================================================
function delete_security_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local sg_id="${1}"
  
   aws ec2 delete-security-group --group-id "${sg_id}" >> /dev/null 
  
   return 0
}

#===============================================================================
# Allow access to the traffic incoming from a CIDR block.  
#
# Globals:
#  None
# Arguments:
# +sg_id           -- The Security Group identifier.
# +port            -- The TCP port
# +cidr            -- The CIDR block from which incoming traffic is allowed.
# Returns:      
#  None
#===============================================================================
function allow_access_from_cidr()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local sg_id="${1}"
   local port="${2}"
   local cidr="${3}" 

   aws ec2 authorize-security-group-ingress \
                   --group-id "${sg_id}" \
                   --protocol tcp \
                   --port "${port}" \
                   --cidr "${cidr}" >> /dev/null
 
   return 0
}

#===============================================================================
# Allows access to the traffic incoming from another Security Group.
#
# Globals:
#  None
# Arguments:
# +sg_id           -- The Security Group identifier.
# +port            -- The TCP port.
# +from_sg_id      -- The Security Group identifier from which incoming traffic 
#                     is allowed.
# Returns:      
#  None
#===============================================================================
function allow_access_from_security_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local sg_id="${1}"
   local port="${2}"
   local from_sg_id="${3}" 

   aws ec2 authorize-security-group-ingress \
                        --group-id "${sg_id}" \
                        --protocol tcp \
                        --port "${port}" \
                        --source-group "${from_sg_id}" >> /dev/null 

   return 0
}

#===============================================================================
# Revokes access to the traffic incoming from another Security Group.  
#
# Globals:
#  None
# Arguments:
# +sg_id           -- The Security Group identifier.
# +port            -- The TCP port.
# +from_sg_id      -- The Security Group identifier from which incoming traffic 
#                     is revoked.
# Returns:      
#  None
#===============================================================================
function revoke_access_from_security_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local sg_id="${1}"
   local port="${2}"
   local from_sg_id="${3}" 

   aws ec2 revoke-security-group-ingress \
                      --group-id "${sg_id}" \
                      --protocol tcp \
                      --port "${port}" \
                      --source-group "${from_sg_id}" >> /dev/null

   return 0
}

#===============================================================================
# Revokes access to the traffic incoming from a specific CIDR block.  
#
# Globals:
#  None
# Arguments:
# +sg_id           -- The Security Group identifier.
# +port            -- The TCP port.
# +src_cidr        -- The CIDR block from which incoming traffic 
#                     is revoked.
# Returns:      
#  None
#===============================================================================
function revoke_access_from_cidr()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local sg_id="${1}"
   local port="${2}"
   local src_cidr="${3}" 

   aws ec2 revoke-security-group-ingress \
                      --group-id "${sg_id}" \
                      --protocol tcp \
                      --port "${port}" \
                      --cidr "${src_cidr}" >> /dev/null

   return 0
}

#===============================================================================
# Checks if a access on a TCP port is granted to traffic incoming from a 
# specific Security Group. 
#
# Globals:
#  None
# Arguments:
# +sg_id           -- The Security Group identifier.
# +port            -- The TCP port.
# +from_sg_id      -- The Security Group identifier from which incoming traffic 
#                     is allowed.
# Returns:      
#  The group identifier if the access is granted, blanc otherwise.
#===============================================================================
function check_access_from_group_is_granted()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local sg_id="${1}"
   local port="${2}"
   local from_sg_id="${3}" 
   local id

   id="$(aws ec2 describe-security-groups \
             --group-ids="${sg_id}" \
             --filters Name=ip-permission.to-port,Values="${port}" \
             --query "SecurityGroups[?IpPermissions[?contains(UserIdGroupPairs[].GroupId, '${from_sg_id}')]].{GroupId: GroupId}" \
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
# +sg_id           -- The Security Group identifier.
# +port            -- The TCP port.
# +src_cidr        -- The CIDR block from which incoming is allowed.
# Returns:      
#  The group identifier if the access is granted, blanc otherwise.
#===============================================================================
function check_access_from_cidr_is_granted()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local sg_id="${1}"
   local port="${2}"
   local src_cidr="${3}" 
   local id
     
   id="$(aws ec2 describe-security-groups \
               --group-ids="${sg_id}" \
               --filters Name=ip-permission.to-port,Values="${port}" \
               --query "SecurityGroups[?IpPermissions[?contains(IpRanges[].CidrIp, '${src_cidr}')]].{GroupId: GroupId}" \
               --output text)"           
                        
   echo "${id}"
   
   return 0
}

#===============================================================================
# Returns an Instance status.
#
# Globals:
#  None
# Arguments:
# +instance_nm     -- The Instance name.
# Returns:      
#  The status of the Instance, or blanc if the Instance is not found.  
#===============================================================================
function get_instance_status()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local instance_nm="${1}"
   local instance_st
  
   instance_st="$(aws ec2 describe-instances \
                            --filters Name=tag-key,Values='Name' \
                            --filters Name=tag-value,Values="${instance_nm}" \
                            --query 'Reservations[*].Instances[*].State.Name' \
                            --output text )"

   echo "${instance_st}"
 
   return 0
}

#===============================================================================
# Returns the public IP address associated to an Instance, by name.
#
# Globals:
#  None
# Arguments:
# +instance_nm     -- The Instance name.
# Returns:      
#  The Instance public address, or blanc if the Instance is not found.  
#===============================================================================
function get_public_ip_address_associated_with_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local instance_nm="${1}"
   local instance_ip
  
   instance_ip="$(aws ec2 describe-instances \
                            --filters Name=tag-key,Values=Name \
                            --filters Name=tag-value,Values="${instance_nm}" \
                            --query 'Reservations[*].Instances[*].PublicIpAddress' \
                            --output text )"

   echo "${instance_ip}"
 
   return 0
}

#===============================================================================
# Returns the private IP address associated to an Instance, by name.
#
# Globals:
#  None
# Arguments:
# +instance_nm     -- The Instance name.
# Returns:      
#  The Instance private address, or blanc if the Instance is not found.  
#===============================================================================
function get_private_ip_address_associated_with_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local instance_nm="${1}"
   local instance_ip
  
   instance_ip="$(aws ec2 describe-instances \
                            --filters Name=tag-key,Values=Name \
                            --filters Name=tag-value,Values="${instance_nm}" \
                            --query 'Reservations[*].Instances[*].PrivateIpAddress' \
                            --output text )"

   echo "${instance_ip}"
 
   return 0
}

#===============================================================================
# Returns the Instance identifier by name.
#
# Globals:
#  None
# Arguments:
# +instance_nm     -- The Instance name.
# Returns:      
#  The Instance identifier, or blanc if the Instance is not found.  
#===============================================================================
function get_instance_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local instance_nm="${1}"
   local instance_id
 
   instance_id="$(aws ec2 describe-instances \
                        --filters Name=tag-key,Values=Name \
                        --filters Name=tag-value,Values="${instance_nm}" \
                        --query 'Reservations[*].Instances[*].InstanceId' \
                        --output text)"

   echo "${instance_id}"
 
   return 0
}

#===============================================================================
# Launches an temporary Instance using an AMI and waits until it is available.
# The Instance is assigned a Public IP address by EC2.
# Globals:
#  None
# Arguments:
# +sg_id          -- The Security Group identifier.
# +subnet_id      -- The Subnet identifier.
# Returns:      
#  None    
#===============================================================================
function run_base_instance()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local sg_id="${1}"
   local subnet_id="${2}"
   local instance_id
 
   __run_instance "${BASE_AMI_ID}" \
                                "${SHARED_BASE_INSTANCE_NM}" \
                                "${SHARED_BASE_INSTANCE_TYPE}" \
                                "${SHARED_BASE_INSTANCE_ROOT_DEV_NM}" \
                                "${SHARED_BASE_INSTANCE_EBS_VOL_SIZE}" \
                                "${sg_id}" \
                                "${subnet_id}" \
                                "${SHARED_BASE_INSTANCE_PRIVATE_IP}" \
                                true \
                                "${SHARED_BASE_INSTANCE_KEY_PAIR_NM}" \
                                "${DEPLOY_ZONE_1}"
   
   return 0
}

#===============================================================================
# Launches the Admin Instance using the secured Shared AMI and waits until it is 
# available. The instance isn't assigned a public IP, so the IP has to be 
# assigned separately.
#
# Globals:
#  None
# Arguments:
# +shared_ami_id  -- The Shared Image identifier from wich the Instance is run.
# +sg_id          -- The Security Group identifier.
# +subnet_id      -- The Subnet identifier.
# Returns:      
#  None    
#===============================================================================
function run_admin_instance()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local shared_ami_id="${1}"
   local sg_id="${2}"
   local subnet_id="${3}"
   local instance_id
 
   __run_instance "${shared_ami_id}" \
                                "${SERVER_ADMIN_NM}" \
                                "${SERVER_ADMIN_TYPE}" \
                                "${SERVER_ADMIN_ROOT_DEV_NM}" \
                                "${SERVER_ADMIN_EBS_VOL_SIZE}" \
                                "${sg_id}" \
                                "${subnet_id}" \
                                "${SERVER_ADMIN_PRIVATE_IP}" \
                                false \
                                "${SERVER_ADMIN_KEY_PAIR_NM}" \
                                "${DEPLOY_ZONE_1}"
   
   return 0
}

#===============================================================================
# Launches a WebPhp Instance using the secured Shared AMI and waits until it is 
# available. The instance isn't assigned a public IP, so the IP has to be 
# assigned separately.
#
# Globals:
#  webphp_id:     -- The identifier of the webphp box, ex. 1,2, ...
# Arguments:
# +shared_ami_id  -- The Shared Image identifier from wich the Instance is run.
# +instance_nm    -- The name of the instance.
# +sg_id          -- The Security Group identifier.
# +subnet_id      -- The Subnet identifier.
# +key_pair_nm    -- The key pair name.
# Returns:      
#  None    
#===============================================================================
function run_webphp_instance()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local shared_ami_id="${1}"
   local instance_nm="${2}"
   local sg_id="${3}"
   local subnet_id="${4}"
   local key_pair_nm="${5}"
 
   __run_instance "${shared_ami_id}" \
                  "${instance_nm}" \
                  "${SERVER_WEBPHP_TYPE}" \
                  "${SERVER_WEBPHP_ROOT_DEV_NM}" \
                  "${SERVER_WEBPHP_EBS_VOL_SIZE}" \
                  "${sg_id}" \
                  "${subnet_id}" \
                  "${SERVER_WEBPHP_PRIVATE_IP/<ID>/"${webphp_id}"}" \
                  false \
                  "${key_pair_nm}" \
                  "${DEPLOY_ZONE_1}"
   
   return 0
}

#===============================================================================
# Runs an Instance using an AMI and waits until it is available.
# The EBS volume is deleted on termination.
#
# Globals:
#  None
# Arguments:
# +image_id       -- The Image identifier from wich the instance is created.
# +instance_nm    -- The Instance name.
# +instance_type  -- The Instance Type, ex. 't2.micro'.
# +root_dev_nm    -- The the device name from which the instance is booted.
# +ebs_vol_size   -- The EBS volume size.
# +sg_id          -- The Security Group identifier.
# +subnet_id      -- The Subnet identifier.
# +priv_ip_add    -- The private IP Address of the Instance.
# +pub_ip_add     -- If 'true', a public IP address will be assigned to the new
#                    instance in the VPC, if 'false' none.
# +key_pair_nm    -- The Key Pair name used to SSH into the Instance.
# +az_nm          -- Availability Zone where the Instance is deployed.

# Returns:      
#  None    
#===============================================================================
function __run_instance()
{
   if [[ $# -lt 11 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local image_id="${1}"
   local instance_nm="${2}"
   local instance_type="${3}"
   local root_dev_nm="${4}"
   local ebs_vol_size="${5}"
   local sg_id="${6}"
   local subnet_id="${7}"
   local priv_ip_add="${8}"
   local pub_ip_add="${9}"
   local key_pair_nm="${10}"
   local az_nm="${11}"
   local instance_id
   
   if [[ true == "${pub_ip_add}" ]]
   then
      instance_id=$(aws ec2 run-instances \
                              --image-id "${image_id}" \
                              --key-name "${key_pair_nm}" \
                              --security-group-ids "${sg_id}" \
                              --instance-type "${instance_type}" \
                              --placement "AvailabilityZone=${az_nm},Tenancy=default" \
                              --subnet-id "${subnet_id}" \
                              --private-ip-address "${priv_ip_add}" \
                              --associate-public-ip-address \
                              --block-device-mapping "DeviceName=${root_dev_nm},Ebs={DeleteOnTermination=true,VolumeSize=${ebs_vol_size}}" \
                              --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value='${instance_nm}'}]" \
                              --output text \
                              --query 'Instances[*].InstanceId')
   else
      instance_id=$(aws ec2 run-instances \
                              --image-id "${image_id}" \
                              --key-name "${key_pair_nm}" \
                              --security-group-ids "${sg_id}" \
                              --instance-type "${instance_type}" \
                              --placement "AvailabilityZone=${az_nm},Tenancy=default" \
                              --subnet-id "${subnet_id}" \
                              --private-ip-address "${priv_ip_add}" \
                              --no-associate-public-ip-address \
                              --block-device-mapping "DeviceName=${root_dev_nm},Ebs={DeleteOnTermination=true,VolumeSize=${ebs_vol_size}}" \
                              --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value='${instance_nm}'}]" \
                              --output text \
                              --query 'Instances[*].InstanceId')   
   fi
   
   aws ec2 wait instance-status-ok --instance-ids "${instance_id}"

   return 0
}

#===============================================================================
# Stops the Instance and waits for it to stop.
#
# Globals:
#  None
# Arguments:
# +instance_id     -- The Instance identifier.
# Returns:      
#  None
#===============================================================================
function stop_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local instance_id="${1}"

   aws ec2 stop-instances --instance-ids "${instance_id}" >> /dev/null
   aws ec2 wait instance-stopped --instance-ids "${instance_id}" 

   return 0
}

#===============================================================================
# Deletes the Instance and waits for its termination. Terminated Instances 
# remain visible after termination for approxi-mately one hour. Any attached EBS 
# volumes with the DeleteOnTermination block device mapping parameter set to 
# true are automatically deleted.
#
# Globals:
#  None
# Arguments:
# +instance_id     -- The Instance identifier.
# Returns:      
#  None
#===============================================================================
function delete_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local instance_id="${1}"

   aws ec2 terminate-instances --instance-ids "${instance_id}" >> /dev/null

   aws ec2 wait instance-terminated --instance-ids "${instance_id}" 

   return 0
}

#===============================================================================
# Creates an Amazon EBS-backed AMI from an Amazon EBS-backed Instance that is 
# either running or stopped. The function wait until the image is available.
# Globals:
#  None
# Arguments:
# +instance_id    -- The Instance identifier.
# +img_nm         -- The Image name.
# +img_desc       -- The Image description.
# Returns:      
#  The Image identifier.    
#===============================================================================
function create_image()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local instance_id="${1}"
   local img_nm="${2}"
   local img_desc="${3}"
   local img_id

   img_id="$(aws ec2 create-image \
                    --instance-id "${instance_id}" \
                    --name "${img_nm}" \
                    --description "${img_desc}" \
                    --query 'ImageId' \
                    --output text)" >> /dev/null
  
   aws ec2 wait image-available --image-ids "${img_id}"
 
   echo "${img_id}"

   return 0
}

#===============================================================================
# Returns the AMI identifier by name.
# Globals:
#  None
# Arguments:
# +img_nm     -- The Image name.
# Returns:      
#  The Image identifier.
#===============================================================================
function get_image_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local img_nm="${1}"
   local img_id

   img_id="$(aws ec2 describe-images \
                   --filters Name=name,Values="${img_nm}" \
                   --query 'Images[*].ImageId' \
                   --output text)"
  
   echo "${img_id}"
 
   return 0
}

#===============================================================================
# Returns the list of Image Snapshot identifiers by Image name.
# The returned list is a string where the identifiers are separated by space. 
#
# Globals:
#  None
# Arguments:
# +img_nm     -- Image name.
# Returns:      
#  The list of Image Snapshot identifiers, or blanc if no Snapshot is found.  
#===============================================================================
function get_image_snapshot_ids()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local img_nm="${1}"

   # AWS CLI provides built-in JSON-based output filtering capabilities with the --query option,
   # a JMESPATH expression is used as a filter. 
   local img_snapshot_ids

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
# +img_id     -- The Image identifier.
# Returns:      
#  None
#========================================================
function delete_image()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local img_id="${1}"

   aws ec2 deregister-image --image-id "${img_id}"

   return 0
}

#===============================================================================
# Deletes a Snapshot by identifier. The Image must be 
# deregisterd first.
#
# Globals:
#  None
# Arguments:
# +img_snapshot_id     -- The Image Snapshot identifier.
# Returns:      
#  None
#========================================================
function delete_image_snapshot()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local img_snapshot_id="${1}"

   aws ec2 delete-snapshot --snapshot-id "${img_snapshot_id}" >> /dev/null

   return 0
}

#===============================================================================
# Returns the the Key Pair identifyer by name.
#
# Globals:
#  None
# Arguments:
# +keypair_nm     -- The Key Pair name.
# Returns:      
#  The Key Pair identifier, or blanc if it is not found.  
#===============================================================================
function get_key_pair_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local keypair_nm="${1}"
   local keypair_id
  
   keypair_id="$(aws ec2 describe-key-pairs \
                        --filters Name='key-name',Values="${keypair_nm}" \
	                --query 'KeyPairs[*].KeyPairId' \
	                --output text)"

   echo "${keypair_id}"
 
   return 0
}

#===============================================================================
# Creates a 2048-bit RSA Key Pair with the specified name. The Public Key is
# stored by Amazon EC2 and the Private Key is saved in a local directory. 
# The Private Key is saved as an unencrypted PEM encoded PKCS#1 
# Private Key. If a key with the specified name already exists, throws an error.
#
# You must provide the key pair to Amazon EC2 when you create the instance, 
# and then use that key pair to authenticate when you connect to the instance.
# Amazon EC2 doesn't keep a copy of your private key, there is no way to recover 
# a private key if you lose it.
#
# Globals:
#  None
# Arguments:
# +keypair_nm     -- The Key Pair name.
# +keypair_dir    -- The local directory where the Private Key is stored.
# Returns:      
#  None
#===============================================================================
function create_key_pair()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local keypair_nm="${1}"
   local keypair_dir="${2}"
   local private_key
   local exist
   
   exist="$(get_key_pair_id "${keypair_nm}")"
   
   if [[ -n "${exist}" ]]
   then
      echo "Error: ${keypair_nm} already exists"
      exit 1
   fi
   
   private_key="$(get_private_key_path "${keypair_nm}" "${keypair_dir}")"

   aws ec2 create-key-pair --key-name "${keypair_nm}" \
                           --query 'KeyMaterial' \
                           --output text > "${private_key}" 

   ## chown root:root "${private_key}"
   chmod 400 "${private_key}"
  
   return 0
}

#===============================================================================
# Returns the path to a Private Key file.
#
# Globals:
#  None
# Arguments:
# +keypair_nm     -- The Key Pair name.
# +keypair_dir    -- The local directory where the Private Key is stored.
# Returns:      
#  The Private Key path.
#===============================================================================
function get_private_key_path()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local keypair_nm="${1}"
   local keypair_dir="${2}"
   local private_key="${keypair_dir}/${keypair_nm}".pem
   
   echo "${private_key}"
  
   return 0
}

#===============================================================================
# Deletes the Key Pair on AWS EC2 and the Private Key in the local directory.
#
# You must provide the key pair to Amazon EC2 when you create the instance, 
# and then use that key pair to authenticate when you connect to the instance.
# Amazon EC2 doesn't keep a copy of your private key, there is no way to recover 
# a private key if you lose it.
#
#
# Globals:
#  None
# Arguments:
# +keypair_nm     -- The Key Pair name.
# +keypair_dir    -- The local directory where the Private Key is stored.
# Returns:      
#  None
#===============================================================================
function delete_key_pair()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local keypair_nm="${1}"
   local keypair_dir="${2}"
   local private_key
   
   private_key="$(get_private_key_path "${keypair_nm}" "${keypair_dir}")"
   
   # Delete the local Private Key.
   rm -f "${private_key:?}"

   # Delete the Key Pair on EC2.
   aws ec2 delete-key-pair --key-name "${keypair_nm}"

   return 0
}

#===============================================================================
# Returns the public IP address allocation identifier. If the address is not 
# allocated with your account, a blanc string is returned.
#
# Globals:
#  None
# Arguments:
# +eip     -- The Elastic IP Public address.
# Returns:      
#  The allocation identifier, or blanc if the address is not allocate with your
#  account.  
#===============================================================================
function get_allocation_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local eip="${1}"
   local allocation_id
                         
   allocation_id="$(aws ec2 describe-addresses \
                     --filter Name=public-ip,Values="${eip}" \
                     --query 'Addresses[*].AllocationId' \
                     --output text)"

   echo "${allocation_id}"
 
   return 0
}

#===============================================================================
# Returns a list of allocation identifiers associated with your account.
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
   local allocation_ids
                         
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
   local eip_list
   
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
# Allocates an Elastic IP address to your AWS account. 
# This method is used when there isn't any unused address available in your 
# account.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  The IP address allocated to your account.  
#===============================================================================
function allocate_public_ip_address()
{
   local eip
  
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
# +allocation_id   -- Allocation identifier.
# Returns:      
#  None 
#===============================================================================
function release_public_ip_address()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local allocation_id="${1}"

   ec2 release-address --allocation-id "${allocation_id}" >> /dev/null

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
#  +allocation_ids    The list
# Returns:      
#  None 
#===============================================================================
function release_all_public_ip_addresses()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi
   
   local allocation_ids="${1}"
                         
   for id in ${allocation_ids}
   do
      aws ec2 release-address --allocation-id "${id}" >> /dev/null
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
# +eip             -- The public IP address.
# +instance_id     -- The Instance identifier.
# Returns:      
#  None 
#===============================================================================
function associate_public_ip_address_to_instance()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: Missing mandatory arguments'
      exit 1
   fi

   local eip="${1}"
   local instance_id="${2}"
  
   aws ec2 associate-address \
               --instance-id "${instance_id}" \
               --public-ip "${eip}" >> /dev/null

   return 0
}

