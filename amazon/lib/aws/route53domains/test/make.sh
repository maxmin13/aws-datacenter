__RESULT='' 
counter=0

##
##
##
echo 'Starting route53domains.sh script tests ...'
echo
##
##
##

################################################
## TEST: validate_dns_domain
################################################

#
# Missing parameter.
#

set +e
validate_dns_domain > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing validate_dns_domain with missing parameter.'
   counter=$((counter +1))
fi 

#
# Wrong format, not it TLD.
#

valid=''
validate_dns_domain 'maxmin.com' > /dev/null 2>&1 
valid="${__RESULT}"

if [[ 'true' == "${valid}" ]]
then
   echo 'ERROR: testing validate_dns_domain wrong domain name format 1.'
   counter=$((counter +1))
fi 

#
# Wrong format, starts by dash.
#

valid=''
validate_dns_domain '-maxmin.it' > /dev/null 2>&1 
valid="${__RESULT}"

if [[ 'true' == "${valid}" ]]
then
   echo 'ERROR: testing validate_dns_domain wrong domain name format 2.'
   counter=$((counter +1))
fi

#
# Wrong format
#

valid=''
validate_dns_domain '.it' > /dev/null 2>&1 
valid="${__RESULT}"

if [[ 'true' == "${valid}" ]]
then
   echo 'ERROR: testing validate_dns_domain wrong domain name format 3.'
   counter=$((counter +1))
fi

#
# Success.
#

valid=''
validate_dns_domain 'www.maxmin.it' > /dev/null 2>&1 
valid="${__RESULT}"

if [[ 'false' == "${valid}" ]]
then
   echo 'ERROR: testing validate_dns_domain wrong domain name format.'
   counter=$((counter +1))
fi  

#
# Success.
#

valid=''
validate_dns_domain 'maxmin.it' > /dev/null 2>&1 
valid="${__RESULT}"

if [[ 'false' == "${valid}" ]]
then
   echo 'ERROR: testing validate_dns_domain wrong domain name format.'
   counter=$((counter +1))
fi 

echo 'validate_dns_domain tests completed.'

####################################################
## TEST: check_domain_availability
####################################################

#
# Missing parameter.
#

set +e
check_domain_availability > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing check_domain_availability with missing parameter.'
   counter=$((counter +1))
fi

#
# Domain not available.
#

set +e
check_domain_availability 'google.it' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing check_domain_availability.'
   counter=$((counter +1))
fi 

availability="${__RESULT}"

if [[ 'AVAILABLE' == "${availability}" ]]
then
   echo 'ERROR: checking domain is registered with the account, the domain is not available.'
   return "${exit_code}"
fi

echo 'check_domain_availability tests completed.'

####################################################
## TEST: check_domain_is_registered_with_the_account
####################################################

#
# Missing parameter.
#

set +e
check_domain_is_registered_with_the_account > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing check_domain_is_registered_with_the_account with missing parameter.'
   counter=$((counter +1))
fi 

#
# Domain not in the account.
#

set +e
check_domain_is_registered_with_the_account 'google.com' > /dev/null 2>&1 
exit_code=$?
set -e
   
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: checking domain is registered with the account.'
   return "${exit_code}"
fi

is_registered="${__RESULT}"

if [[ 'true' == "${is_registered}" ]]
then
   echo 'ERROR: checking domain is registered with the account, the domain is not registered.'
   return "${exit_code}"
fi

echo 'check_domain_is_registered_with_the_account tests completed.'

################################################
## TEST: register_domain
################################################

#
# Missing parameter.
#

set +e
register_domain > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing register_domain with missing parameter.'
   counter=$((counter +1))
fi 

#
# Request file not found.
#

set +e
register_domain 'register_domain_request_template.json' > /dev/null 2>&1
exit_code=$?
set -e

if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing register_domain request file not found.'
   counter=$((counter +1))
fi 

echo 'register_domain tests completed.'

################################################
## TEST: update_domain_registration_name_servers
################################################

#
# Missing parameter.
#

set +e
update_domain_registration_name_servers 'maxmin.it' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing update_domain_registration_name_servers with missing parameter.'
   counter=$((counter +1))
fi 

#
# Less than 4 servers.
#

set +e
update_domain_registration_name_servers 'maxmin.it' 'ns-1.awsdns-01.org ns-2.awsdns-02.co.uk ns-3.awsdns-03.net' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing update_domain_registration_name_servers with only 3 name servers.'
   counter=$((counter +1))
fi 

echo 'update_domain_registration_name_servers tests completed.'

###########################################
## TEST: get_request_status
###########################################

#
# Missing parameter.
#

set +e
get_request_status > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing get_request_status with missing parameter.'
   counter=$((counter +1))
fi 

#
# Not existing request.
#

set +e
get_request_status 'xxx' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing get_request_status with not existing request.'
   counter=$((counter +1))
fi 

status="${__RESULT}"

# A blanc string is expected.
if test -n "${status}"
then
   echo 'ERROR: testing get_request_status with not existing request 2.'
   counter=$((counter +1))
fi 

echo 'get_request_status tests completed.'

###########################################
## TEST: __create_name_servers_list
###########################################

#
# Missing parameter.
#

set +e
__create_name_servers_list > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __create_name_servers_list with missing parameter.'
   counter=$((counter +1))
fi 

#
# Not a string of 4 servers.
#

set +e
__create_name_servers_list 'ns-1.awsdns-01.org ns-2.awsdns-02.co.uk ns-3.awsdns-03.net' > /dev/null 2>&1 
exit_code=$?
set -e

# An error is expected.
if test "${exit_code}" -ne 128
then
   echo 'ERROR: testing __create_name_servers_list with only 3 name servers.'
   counter=$((counter +1))
fi 

#
# Success.
#

set +e
__create_name_servers_list 'ns-1.awsdns-01.org ns-2.awsdns-02.co.uk ns-3.awsdns-03.net ns-4.awsdns-04.com' > /dev/null 2>&1 
exit_code=$?
set -e

# No error is expected.
if test "${exit_code}" -ne 0
then
   echo 'ERROR: testing __create_name_servers_list.'
   counter=$((counter +1))
fi

name_servers_json="${__RESULT}"

# Check the JSON object returned.

## Validate JSON.
if jq -e . >/dev/null 2>&1 <<< "${name_servers_json}"
then
   # Get the first name server.
   name_server_0="$(echo "${name_servers_json}" | jq -r '.[0].Name')"
    
   if [[ 'ns-1.awsdns-01.org' != "${name_server_0}" ]]
   then
      echo "ERROR: testing __create_name_servers_list wrong first element."
      counter=$((counter +1))
   fi

   # Get the second name server.
   name_server_1="$(echo "${name_servers_json}" | jq -r '.[1].Name')"
    
   if [[ 'ns-2.awsdns-02.co.uk' != "${name_server_1}" ]]
   then
      echo "ERROR: testing __create_name_servers_list wrong second element."
      counter=$((counter +1))
   fi

   # Get the third name server.
   name_server_2="$(echo "${name_servers_json}" | jq -r '.[2].Name')"
    
   if [[ 'ns-3.awsdns-03.net' != "${name_server_2}" ]]
   then
      echo "ERROR: testing __create_name_servers_list wrong third element."
      counter=$((counter +1))
   fi

   # Get the fourth name server.
   name_server_3="$(echo "${name_servers_json}" | jq -r '.[3].Name')"
    
   if [[ 'ns-4.awsdns-04.com' != "${name_server_3}" ]]
   then
      echo "ERROR: testing __create_name_servers_list wrong fourth element."
      counter=$((counter +1))
   fi
fi

echo 'get_request_status tests completed.'

##############################################
# Count the errors.
##############################################

echo

if [[ "${counter}" -gt 0 ]]
then
   echo "route53domains.sh script test completed with ${counter} errors."
else
   echo 'route53domains.sh script test successfully completed.'
fi

echo


