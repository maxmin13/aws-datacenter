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

echo
echo '***********'
echo 'Data center'
echo '***********'
echo

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"

if [[ -n "${dtc_id}" ]]
then
   echo 'WARN: the data center has already been created.'
else
   ## Make a new VPC with a master 10.0.10.0/16 subnet
   create_datacenter "${DTC_NM}"
   get_datacenter_id "${DTC_NM}"
   dtc_id="${__RESULT}"
    
   echo 'Data center created.'
fi

## 
## Internet gateway 
## 

## Create an internet gateway (to allow access out to the Internet)
get_internet_gateway_id "${DTC_INTERNET_GATEWAY_NM}"
internet_gate_id="${__RESULT}"

if [[ -n "${internet_gate_id}" ]]
then
   echo 'WARN: the internet gateway has already been created.'
else
   create_internet_gateway "${DTC_INTERNET_GATEWAY_NM}" "${dtc_id}"
   get_internet_gateway_id "${DTC_INTERNET_GATEWAY_NM}"
   internet_gate_id="${__RESULT}"
	              
   echo 'Internet gateway created.' 
fi
  
## Check if the internet gateway is already attached to the VPC.
get_internet_gateway_attachment_status "${DTC_INTERNET_GATEWAY_NM}" "${dtc_id}"
attach_status="${__RESULT}"

if [[ 'available' != "${attach_status}" ]]
then
   attach_internet_gateway "${internet_gate_id}" "${dtc_id}"
   
   echo 'The internet gateway has been attached to the Data Center.'	
fi

## 
## Route table
## 

get_route_table_id "${DTC_ROUTE_TABLE_NM}"
rtb_id="${__RESULT}"
							
if [[ -n "${rtb_id}" ]]
then
   echo 'WARN: the route table has already been created.'
else
   create_route_table "${DTC_ROUTE_TABLE_NM}" "${dtc_id}"
   get_route_table_id "${DTC_ROUTE_TABLE_NM}"
   rtb_id="${__RESULT}"
                   
   echo 'Created route table.'
fi

set_route "${rtb_id}" "${internet_gate_id}" '0.0.0.0/0' > /dev/null

echo 'Created route that points all traffic to the internet gateway.'

## 
## Main subnet 
## 

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
main_subnet_id="${__RESULT}"

if [[ -n "${main_subnet_id}" ]]
then
   echo 'WARN: the main subnet has already been created.'
else
   create_subnet "${DTC_SUBNET_MAIN_NM}" \
       "${DTC_SUBNET_MAIN_CIDR}" "${DTC_AZ_1}" "${dtc_id}" "${rtb_id}"
       
   get_subnet_id "${DTC_SUBNET_MAIN_NM}"
   main_subnet_id="${__RESULT}"
   
   echo "The main subnet has been created in the ${DTC_AZ_1} availability zone and associated to the route table."    
fi

## 
## Backup subnet 
## 

get_subnet_id "${DTC_SUBNET_BACKUP_NM}"
backup_subnet_id="${__RESULT}"	                
	                
if [[ -n "${backup_subnet_id}" ]]
then
   echo 'WARN: the backup subnet has already been created.'
else
   create_subnet "${DTC_SUBNET_BACKUP_NM}" \
       "${DTC_SUBNET_BACKUP_CIDR}" "${DTC_AZ_2}" "${dtc_id}" "${rtb_id}"
       
   get_subnet_id "${DTC_SUBNET_BACKUP_NM}"
   backup_subnet_id="${__RESULT}"    

   echo "The backup subnet has been created in the ${DTC_AZ_2} availability zone and associated to the route table."
fi

echo
echo 'Data center up and running.'

