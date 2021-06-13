#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '***********'
echo 'Data Center'
echo '***********'
echo

dtc_id="$(get_datacenter_id "${DTC_NM}")"

if [[ -z "${dtc_id}" ]]
then
   echo '* WARN: Data Center not found.'
else
   echo "* Data Center ID: ${dtc_id}"
fi

internet_gate_id="$(get_internet_gateway_id "${DTC_INTERNET_GATEWAY_NM}")"

if [[ -z "${internet_gate_id}" ]]
then
   echo '* WARN: Internet Gateway not found.'
else
   echo "* Internet Gateway ID: ${internet_gate_id}."
fi

main_subnet_id="$(get_subnet_id "${DTC_SUBNET_MAIN_NM}")"

if [[ -z "${main_subnet_id}" ]]
then
   echo '* WARN: main Subnet not found.'
else
   echo "* main Subnet ID: ${main_subnet_id}."
fi

backup_subnet_id="$(get_subnet_id "${DTC_SUBNET_BACKUP_NM}")"

if [[ -z "${backup_subnet_id}" ]]
then
   echo '* WARN: backup Subnet not found.'
else
   echo "* backup Subnet ID: ${backup_subnet_id}."
fi

route_table_id="$(get_route_table_id "${DTC_ROUTE_TABLE_NM}")"

if [[ -z "${route_table_id}" ]]
then
   echo '* WARN: Route Table not found.'
else
   echo "* Route Table ID: ${route_table_id}."
fi

echo

## 
## Internet gateway
## 

if [[ -n "${internet_gate_id}" ]]
then
   if [ -n "${dtc_id}" ]; then     
      gate_status="$(get_internet_gateway_attachment_status "${DTC_INTERNET_GATEWAY_NM}" "${dtc_id}")"
      if [ -n "${gate_status}" ]; then
         aws ec2 detach-internet-gateway --internet-gateway-id  "${internet_gate_id}" --vpc-id "${dtc_id}"
         echo 'Internet Gateway detached from VPC.'
      fi
   fi
    
   delete_internet_gateway "${internet_gate_id}"
   echo 'Internet Gateway deleted.'
fi

## 
## Main Subnet 
## 	

if [[ -n "${main_subnet_id}" ]]
then
   delete_subnet "${main_subnet_id}"
   echo 'Main Subnet deleted.'
fi

## 
## Backup Subnet 
## 

if [[ -n "${backup_subnet_id}" ]]
then
   delete_subnet "${backup_subnet_id}"
   echo 'Backup Subnet deleted.'
fi		

## 
## Route table
## 

if [[ -n "${route_table_id}" ]]
then
   delete_route_table "${route_table_id}"
   echo 'Route Table deleted.'
fi

## 
## Data center 
## 

## We can finally delete the VPC, all remaining assets are also deleted (eg route table, default Security Group).
## Tags are deleted automatically when associated resource dies.
                   
if [[ -n "${dtc_id}" ]]
then
   delete_datacenter "${dtc_id}" 
   echo 'Data Center deleted.'
fi                     

echo
