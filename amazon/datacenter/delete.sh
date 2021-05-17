#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo '***********'
echo 'Data Center'
echo '***********'
echo

vpc_id="$(get_vpc_id "${VPC_NM}")"

## **************** ##
## Internet Gateway ##
## **************** ##

gate_id="$(get_internet_gateway_id "${INTERNET_GATEWAY_NM}")"

if [[ -z "${gate_id}" ]]
then
   echo "'${INTERNET_GATEWAY_NM}' internet gateway not found"
else
   if [ -n "${vpc_id}" ]; then     
      gate_status="$(get_internet_gateway_attachment_status "${INTERNET_GATEWAY_NM}" "${vpc_id}")"
      if [ -n "${gate_status}" ]; then
         aws ec2 detach-internet-gateway --internet-gateway-id  "${gate_id}" --vpc-id "${vpc_id}"
         echo "'${INTERNET_GATEWAY_NM}' internet gateway detached from VPC"
      fi
   fi
    
   delete_internet_gateway "${gate_id}"
   echo "'${INTERNET_GATEWAY_NM}' internet gateway deleted"
fi

## *********** ##
## Main Subnet ##
## *********** ##

main_subnet_id="$(get_subnet_id "${SUBNET_MAIN_NM}")"		

if [[ -z "${main_subnet_id}" ]]
then
   echo "'${SUBNET_MAIN_NM}' subnet not found"
else
   delete_subnet "${main_subnet_id}"
   echo "'${SUBNET_MAIN_NM}' subnet deleted"
fi

## ************* ##
## Backup Subnet ##
## ************* ##

backup_subnet_id="$(get_subnet_id "${SUBNET_BACKUP_NM}")"		

if [[ -z "${backup_subnet_id}" ]]
then
   echo "'${SUBNET_BACKUP_NM}' subnet not found"
else
   delete_subnet "${backup_subnet_id}"
   echo "'${SUBNET_BACKUP_NM}' subnet deleted"
fi

## *********** ##
## Route Table ##
## *********** ##

rtb_id="$(get_route_table_id "${ROUTE_TABLE_NM}")"

if [[ -z "${rtb_id}" ]]
then
   echo "'${ROUTE_TABLE_NM}' route table not found"
else
   delete_route_table "${rtb_id}"
   echo "'${ROUTE_TABLE_NM}' route table deleted"
fi

## *********** ##
## Data Center ##
## *********** ##

## We can finally delete the VPC, all remaining assets are also deleted (eg route table, default security group).
## Tags are deleted automatically when associated resource dies.
                   
if [[ -z "${vpc_id}" ]]
then
   echo "'${VPC_NM}' VPC not found"
else
   delete_vpc "${vpc_id}" 
   echo "'${VPC_NM}' VPC deleted"
fi                     

echo 'Data Center components deleted'
echo
