#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##
## Create a load balancer that listens on port 80 HTTP port and forwards the requests to the clients on port 80 HTTP unencrypted.
## The load balancer performs healt-checks of the registered instances. To be marked as healty, the monitored instances must provide 
## the following endpoint to the Load Balancer, ex: HTTP:"8090/elb.htm, the endpoint must return 'ok' response. 
## Check security group permissions and security module override rules.
## If Elastic Load Balancing finds an unhealthy instance, it stops sending traffic to the instance and routes traffic to the healthy instances. 
## The load balancer is usable as soon as any one of your registered instances is in the InService state.
##

echo '*************'
echo 'Load balancer'
echo '*************'
echo

dtc_id="$(get_datacenter_id "${DTC_NM}")"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

subnet_ids="$(get_subnet_ids "${dtc_id}")"

if [[ -z "${subnet_ids}" ]]
then
   echo '* ERROR: subnets not found.'
   exit 1
else
   echo "* subnet IDs: ${subnet_ids}."
fi

echo

## 
## Security group 
## 

sgp_id="$(get_security_group_id "${LBAL_BOX_SEC_GRP_NM}")"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the load balancer security group is already created.'
else
   sgp_id="$(create_security_group "${dtc_id}" "${LBAL_BOX_SEC_GRP_NM}" 'Load balancer security group.')"  
   
   echo 'Created load balancer security group.'
fi

# Check HTTP access from the Internet.
granted_http="$(check_access_from_cidr_is_granted  "${sgp_id}" "${LBAL_BOX_HTTP_PORT}" '0.0.0.0/0')"

if [[ -n "${granted_http}" ]]
then
   echo 'WARN: Internet access to the load balancer already granted.'
else
   allow_access_from_cidr "${sgp_id}" "${LBAL_BOX_HTTP_PORT}" '0.0.0.0/0'
   
   echo 'Granted HTTP access to the load balancer from anywhere in the Internet.'
fi

## 
## Load balancer box
## 

exists="$(get_loadbalancer_dns_name "${LBAL_BOX_NM}")"

if [[ -n "${exists}" ]]
then
   echo 'WARN: load balancer box already created.'
else
   echo 'Creating an HTTP load balancer box ...'
   
   create_http_loadbalancer "${LBAL_BOX_NM}" "${sgp_id}" "${subnet_ids}"
   configure_loadbalancer_health_check "${LBAL_BOX_NM}"

   echo 'HTTP load balancer box created.'
fi  
       
loadbalancer_dns="$(get_loadbalancer_dns_name "${LBAL_BOX_NM}")"

echo
echo "Load Balancer up and running at: ${loadbalancer_dns}."
echo
