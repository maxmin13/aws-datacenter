#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##
## Amazon Virtual Private Cloud (Amazon VPC) enables you to define a virtual networking environment in a private, 
## isolated section of the AWS cloud. Within this virtual private cloud (VPC), you can launch AWS resources such as 
## load balancers and EC2 instances. 
##

echo '***********'
echo 'Data Center'
echo '***********'
echo

vpc_id="$(get_vpc_id "${VPC_NM}")"

if [[ -n "${vpc_id}" ]]
then
   echo "ERROR: The '${VPC_NM}' Data Center has already been created"
   exit 1
fi

## Make a new VPC with a master 10.0.0.0/16 subnet
vpc_id="$(create_vpc "${VPC_NM}")" 
echo "'${VPC_NM}' VPC created"

## *** ##
## DNS ##
## *** ##

## Enable DNS support or modsecurity won't let Apache start...
aws ec2 modify-vpc-attribute --vpc-id "${vpc_id}" --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id "${vpc_id}" --enable-dns-hostnames

echo 'DNS support configured'

## **************** ##
## Internet Gateway ##
## **************** ##

## Create an internet gateway (to allow access out to the Internet)
gateway_id="$(get_internet_gateway_id "${INTERNET_GATEWAY_NM}")"

if [[ -n "${gateway_id}" ]]
then
   echo "ERROR: The '${INTERNET_GATEWAY_NM}' Internet Gateway is already created"
   exit 1
fi
  
gateway_id="$(create_internet_gateway "${INTERNET_GATEWAY_NM}" "${vpc_id}")"
	              
echo "'${INTERNET_GATEWAY_NM}' Internet Gateway created"   

## Check if the Internet Gateway is already attached to the VPC.
attach_status="$(get_internet_gateway_attachment_status "${INTERNET_GATEWAY_NM}" "${vpc_id}")"

if [[ available != "${attach_status}" ]]
then
   attach_internet_gateway "${gateway_id}" "${vpc_id}"
   echo "'${INTERNET_GATEWAY_NM}' Internet Gateway attached to the VPC"	
else
   echo "'${INTERNET_GATEWAY_NM}' Internet Gateway already attached to the VPC"
fi

## *********** ##
## Route Table ##
## *********** ##

rtb_id="$(get_route_table_id "${ROUTE_TABLE_NM}")"
							
if [[ -n "${rtb_id}" ]]
then
   echo "The '${ROUTE_TABLE_NM}' Route Table is already created"
   exit 1
fi

rtb_id="$(create_route_table "${ROUTE_TABLE_NM}" "${vpc_id}")"	
	                
echo "'${ROUTE_TABLE_NM}' custom Route Table created"
set_route "${rtb_id}" "${gateway_id}" '0.0.0.0/0'
echo 'Created Route that points all traffic to the Internet Gateway'

## *********** ##
## Main Subnet ##
## *********** ##

main_subnet_id="$(get_subnet_id "${SUBNET_MAIN_NM}")"

if [[ -n "${main_subnet_id}" ]]
then
   echo "ERROR: The '${SUBNET_MAIN_NM}' Subnet is already created"
   exit 1
fi

echo "Creating '${SUBNET_MAIN_NM}' Subnet"
main_subnet_id="$(create_subnet "${SUBNET_MAIN_NM}" \
                                   "${SUBNET_MAIN_CIDR}" \
                                   "${DEPLOY_ZONE_1}" \
                                   "${vpc_id}" \
                                   "${rtb_id}")"

echo "The '${SUBNET_MAIN_NM}' Subnet has been created in the '${DEPLOY_ZONE_1}' Availability Zone and associated with the Route Table"

## ************* ##
## Backup Subnet ##
## ************* ##

backup_subnet_id="$(get_subnet_id "${SUBNET_BACKUP_NM}")"	                
	                
if [[ -n "${backup_subnet_id}" ]]
then
   echo "ERROR: The '${SUBNET_BACKUP_NM}' Subnet is already created"
   exit 1
fi

echo "Creating '${SUBNET_BACKUP_NM}' Subnet"
backup_subnet_id="$(create_subnet "${SUBNET_BACKUP_NM}" \
                                     "${SUBNET_BACKUP_CIDR}" \
                                     "${DEPLOY_ZONE_2}" \
                                     "${vpc_id}" \
                                     "${rtb_id}")"

echo "The '${SUBNET_BACKUP_NM}' Subnet has been created in the '${DEPLOY_ZONE_2}' Availability Zone and associated with the Route Table"

echo 'Data Center setup completed'
echo
