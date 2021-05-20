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
   echo 'ERROR: the data center has already been created'
   exit 1
fi

## Make a new VPC with a master 10.0.0.0/16 subnet
vpc_id="$(create_vpc "${VPC_NM}")" 
echo 'Data center created'

## 
## Internet gateway 
## 

## Create an internet gateway (to allow access out to the Internet)
internet_gate_id="$(get_internet_gateway_id "${INTERNET_GATEWAY_NM}")"

if [[ -n "${internet_gate_id}" ]]
then
   echo 'ERROR: the internet gateway has already been created'
   exit 1
fi
  
internet_gate_id="$(create_internet_gateway "${INTERNET_GATEWAY_NM}" "${vpc_id}")"
	              
echo 'Internet gateway created'   

## Check if the Internet Gateway is already attached to the VPC.
attach_status="$(get_internet_gateway_attachment_status "${INTERNET_GATEWAY_NM}" "${vpc_id}")"

if [[ available != "${attach_status}" ]]
then
   attach_internet_gateway "${internet_gate_id}" "${vpc_id}"
   echo 'The internet gateway has been attached to the data center'	
fi

## 
## Route table
## 

rtb_id="$(get_route_table_id "${ROUTE_TABLE_NM}")"
							
if [[ -n "${rtb_id}" ]]
then
   echo 'ERROR: the route table has already been created'
   exit 1
fi

rtb_id="$(create_route_table "${ROUTE_TABLE_NM}" "${vpc_id}")"	
	                
echo 'A custom route table has been created'
set_route "${rtb_id}" "${internet_gate_id}" '0.0.0.0/0'
echo 'Created Route that points all traffic to the internet gateway'

## 
## Main subnet 
## 

main_subnet_id="$(get_subnet_id "${SUBNET_MAIN_NM}")"

if [[ -n "${main_subnet_id}" ]]
then
   echo 'ERROR: the main subnet has already been created'
   exit 1
fi

main_subnet_id="$(create_subnet "${SUBNET_MAIN_NM}" \
                                   "${SUBNET_MAIN_CIDR}" \
                                   "${DEPLOY_ZONE_1}" \
                                   "${vpc_id}" \
                                   "${rtb_id}")"

echo "The main subnet has been created in the '${DEPLOY_ZONE_1}' availability zone and associated to the route table"

## 
## Backup subnet 
## 

backup_subnet_id="$(get_subnet_id "${SUBNET_BACKUP_NM}")"	                
	                
if [[ -n "${backup_subnet_id}" ]]
then
   echo 'ERROR: the backup subnet is already created'
   exit 1
fi

backup_subnet_id="$(create_subnet "${SUBNET_BACKUP_NM}" \
                                     "${SUBNET_BACKUP_CIDR}" \
                                     "${DEPLOY_ZONE_2}" \
                                     "${vpc_id}" \
                                     "${rtb_id}")"

echo "The backup subnet has been created in the '${DEPLOY_ZONE_2}' availability zone and associated to the route table"

echo 'Data center up and running'
echo
