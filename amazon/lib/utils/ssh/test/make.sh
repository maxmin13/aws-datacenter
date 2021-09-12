#!/usr/bin/bash

set +o errexit
set +o pipefail
set +o nounset
set +o xtrace
   
counter=0; __RESULT=''; test_dir="${TMP_DIR}/ssh_tests"
       
##
##
##
echo 'Starting ssh_utils.sh script tests ...'
echo
##
##
##

###########################################
## TEST: get_public_key
###########################################

exit_code=0; __RESULT=''; public_key_value='';

mkdir -p "${test_dir}"
ssh-keygen -N '' -q -t rsa -b 4096 -C "${email_add}" -f "${test_dir}"/private_key

#
# Missing argument.
#

set +e
get_public_key 'private_key' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_public_key with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing directory.
#  

set +e
get_public_key 'private_key' 'xxx' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing get_public_key with not existing directory.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
get_public_key 'private_key' "${test_dir}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_public_key.'
   counter=$((counter +1))
fi

# Check the public key is returned.
public_key_value="${__RESULT}"

if [[ -z "${public_key_value}" ]]
then
   echo 'ERROR: testing get_public_key, public key file not returned.'
   counter=$((counter +1))
fi

#
# Not existing key.
#

set +e
get_public_key 'xxx' "${test_dir}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_public_key with not existing key.'
   counter=$((counter +1))
fi

public_key_value="${__RESULT}"

if [[ -n "${public_key_value}" ]]
then
   echo 'ERROR: testing get_public_key, empty string should be returned.'
   counter=$((counter +1))
fi

echo 'get_public_key tests completed.'

rm -rf "${test_dir:?}"

###########################################
## TEST: get_private_key
###########################################

exit_code=0; __RESULT=''; private_key_value='';

mkdir -p "${test_dir}"
ssh-keygen -N '' -q -t rsa -b 4096 -C "${email_add}" -f "${test_dir}"/private_key

#
# Missing argument.
#

set +e
get_private_key 'private_key' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_private_key with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing directory.
#  

set +e
get_private_key 'private_key' 'xxx' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing get_private_key with not existing directory.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
get_private_key 'private_key' "${test_dir}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_private_key.'
   counter=$((counter +1))
fi

# Check the private key is returned.
private_key_value="${__RESULT}"

if [[ -z "${private_key_value}" ]]
then
   echo 'ERROR: testing get_private_key, private key file not returned.'
   counter=$((counter +1))
fi

#
# Not existing key.
#

set +e
get_private_key 'xxx' "${test_dir}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing get_private_key with not existing key.'
   counter=$((counter +1))
fi

private_key_value="${__RESULT}"

if [[ -n "${private_key_value}" ]]
then
   echo 'ERROR: testing get_private_key, empty string should be returned.'
   counter=$((counter +1))
fi

echo 'get_private_key tests completed.'

rm -rf "${test_dir:?}"

###########################################
## TEST: delete_keypair
###########################################

exit_code=0; 

mkdir -p "${test_dir}"
ssh-keygen -N '' -q -t rsa -b 4096 -C "${email_add}" -f "${test_dir}"/private_key

#
# Missing argument.
#

set +e
delete_keypair 'private_key' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_keypair with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing directory.
#  

set +e
delete_keypair 'private_key' 'xxx' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing delete_keypair with not existing directory.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
delete_keypair 'private_key' "${test_dir}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_keypair.'
   counter=$((counter +1))
fi

# Check the private and the public key are deleted.

if [[ -f "${test_dir}"/private_key ]]
then
   echo 'ERROR: testing delete_keypair, private key file not deleted.'
   counter=$((counter +1))
fi

if [[ -f "${test_dir}"/private_key.pub ]]
then
   echo 'ERROR: testing delete_keypair, public key file not deleted.'
   counter=$((counter +1))
fi

#
# Not existing key.
#

set +e
delete_keypair 'xxx' "${test_dir}" > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing delete_keypair twice.'
   counter=$((counter +1))
fi

echo 'delete_keypair tests completed.'

rm -rf "${test_dir:?}"

###########################################
## TEST: create_keypair
###########################################

exit_code=0; 

mkdir -p "${test_dir}"

#
# Missing argument.
#

set +e
create_keypair 'private_key' "${test_dir}" > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 128 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_keypair with missing arguments.'
   counter=$((counter +1))
fi 

#
# Not existing directory.
#  

set +e
create_keypair 'private_key' 'xxx' 'max@email.com' > /dev/null 2>&1
exit_code=$?
set -e

# AN error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing create_keypair with not existing directory.'
   counter=$((counter +1))
fi

#
# Success.
#

set +e
create_keypair 'private_key' "${test_dir}" 'max@email.com' > /dev/null 2>&1
exit_code=$?
set -e

# No error is expected.
if [[ 0 -ne "${exit_code}" ]]
then
   echo 'ERROR: testing create_keypair.'
   counter=$((counter +1))
fi

# Check the private and the public key files exist.

if [[ ! -f "${test_dir}"/private_key ]]
then
   echo 'ERROR: testing create_keypair, private key file not found.'
   counter=$((counter +1))
fi

if [[ ! -f "${test_dir}"/private_key.pub ]]
then
   echo 'ERROR: testing create_keypair, public key file not found.'
   counter=$((counter +1))
fi

#
# Same key twice
#

set +e
create_keypair 'private_key' "${test_dir}" 'max@email.com' > /dev/null 2>&1
exit_code=$?
set -e

# An error is expected.
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'ERROR: testing create_keypair twice.'
   counter=$((counter +1))
fi

echo 'create_keypair tests completed.'

rm -rf "${test_dir:?}"

##############################################
# Count the errors.
##############################################

echo

if [[ "${counter}" -gt 0 ]]
then
   echo "ssh_utils.sh script test completed with ${counter} errors."
else
   echo 'ssh_utils.sh script test successfully completed.'
fi

echo


