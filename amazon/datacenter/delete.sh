#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '***********'
echo 'Data center'
echo '***********'
echo

dtc_id="$(get_datacenter_id "${DTC_NM}")"

if [[ -z "${dtc_id}" ]]
then
   echo '* WARN: data center not found.'
else
   echo "* data center ID: ${dtc_id}"
fi

internet_gate_id="$(get_internet_gateway_id "${DTC_INTERNET_GATEWAY_NM}")"

if [[ -z "${internet_gate_id}" ]]
then
   echo '* WARN: internet gateway not found.'
else
   echo "* internet gateway ID: ${internet_gate_id}."
fi

main_subnet_id="$(get_subnet_id "${DTC_SUBNET_MAIN_NM}")"

if [[ -z "${main_subnet_id}" ]]
then
   echo '* WARN: main subnet not found.'
else
   echo "* main subnet ID: ${main_subnet_id}."
fi

backup_subnet_id="$(get_subnet_id "${DTC_SUBNET_BACKUP_NM}")"

if [[ -z "${backup_subnet_id}" ]]
then
   echo '* WARN: backup subnet not found.'
else
   echo "* backup subnet ID: ${backup_subnet_id}."
fi

route_table_id="$(get_route_table_id "${DTC_ROUTE_TABLE_NM}")"

if [[ -z "${route_table_id}" ]]
then
   echo '* WARN: route table not found.'
else
   echo "* route table ID: ${route_table_id}."
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
   
   echo 'Internet gateway deleted.'
fi

## 
## Main subnet 
## 	

if [[ -n "${main_subnet_id}" ]]
then
   delete_subnet "${main_subnet_id}"
   
   echo 'Main subnet deleted.'
fi

## 
## Backup subnet 
## 

if [[ -n "${backup_subnet_id}" ]]
then
   delete_subnet "${backup_subnet_id}"
   
   echo 'Backup subnet deleted.'
fi		

## 
## Route table
## 

if [[ -n "${route_table_id}" ]]
then
   delete_route_table "${route_table_id}"
   
   echo 'Route table deleted.'
fi

## 
## Data center 
## 

## We can finally delete the VPC, all remaining assets are also deleted (eg route table, default security group..
## Tags are deleted automatically when associated resource dies.
                   
if [[ -n "${dtc_id}" ]]
then
   delete_datacenter "${dtc_id}" 
   
   echo 'Data center deleted.'
fi                     

