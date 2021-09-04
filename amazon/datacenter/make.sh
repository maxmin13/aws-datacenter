#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##
## Amazon Virtual Private Cloud (Amazon VPC) enables you to define a virtual networking environment in a private, 
## isolated section of the AWS cloud. Within this virtual private cloud (VPC), you can launch AWS resources such as 
## Load Balancers and EC2 instances. 
##

echo '***********'
echo 'Data center'
echo '***********'
echo

dtc_id="$(get_datacenter_id "${DTC_NM}")"

if [[ -n "${dtc_id}" ]]
then
   echo 'WARN: the data center has already been created.'
else
   ## Make a new VPC with a master 10.0.0.0/16 subnet
   dtc_id="$(create_datacenter "${DTC_NM}")"
    
   echo 'Data center created.'
fi

## 
## Internet gateway 
## 

## Create an internet gateway (to allow access out to the Internet)
internet_gate_id="$(get_internet_gateway_id "${DTC_INTERNET_GATEWAY_NM}")"

if [[ -n "${internet_gate_id}" ]]
then
   echo 'WARN: the internet gateway has already been created.'
else
   internet_gate_id="$(create_internet_gateway "${DTC_INTERNET_GATEWAY_NM}" "${dtc_id}")"
	              
   echo 'Internet gateway created.' 
fi
  
## Check if the internet gateway is already attached to the VPC.
attach_status="$(get_internet_gateway_attachment_status "${DTC_INTERNET_GATEWAY_NM}" "${dtc_id}")"

if [[ 'available' != "${attach_status}" ]]
then
   attach_internet_gateway "${internet_gate_id}" "${dtc_id}"
   
   echo 'The internet gateway has been attached to the Data Center.'	
fi

## 
## Route table
## 

rtb_id="$(get_route_table_id "${DTC_ROUTE_TABLE_NM}")"
							
if [[ -n "${rtb_id}" ]]
then
   echo 'WARN: the route table has already been created.'
else
   rtb_id="$(create_route_table "${DTC_ROUTE_TABLE_NM}" "${dtc_id}")"	
                   
   echo 'Created route table.'
fi

set_route "${rtb_id}" "${internet_gate_id}" '0.0.0.0/0' > /dev/null

echo 'Created route that points all traffic to the internet gateway.'

## 
## Main subnet 
## 

main_subnet_id="$(get_subnet_id "${DTC_SUBNET_MAIN_NM}")"

if [[ -n "${main_subnet_id}" ]]
then
   echo 'WARN: the main subnet has already been created.'
else
   main_subnet_id="$(create_subnet "${DTC_SUBNET_MAIN_NM}" \
       "${DTC_SUBNET_MAIN_CIDR}" \
       "${DTC_DEPLOY_ZONE_1}" \
       "${dtc_id}" \
       "${rtb_id}")"
   
   echo "The main subnet has been created in the ${DTC_DEPLOY_ZONE_1} availability zone and associated to the route table."    
fi

## 
## Backup subnet 
## 

backup_subnet_id="$(get_subnet_id "${DTC_SUBNET_BACKUP_NM}")"	                
	                
if [[ -n "${backup_subnet_id}" ]]
then
   echo 'WARN: the backup subnet has already been created.'
else
   backup_subnet_id="$(create_subnet "${DTC_SUBNET_BACKUP_NM}" \
       "${DTC_SUBNET_BACKUP_CIDR}" \
       "${DTC_DEPLOY_ZONE_2}" \
       "${dtc_id}" \
       "${rtb_id}")"

   echo "The backup subnet has been created in the ${DTC_DEPLOY_ZONE_2} availability zone and associated to the route table."
fi

echo
echo 'Data center up and running.'
echo
