#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

function wait()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local -r seconds="${1}"
   local count=0
   
   while [[ "${count}" -lt "${seconds}" ]]; do
      printf '.'
      sleep 1
      count=$((count+1))
   done
   
   printf '\n'

   return 0
}

function remove_last_character_if_present()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   __RESULT=''
   local -r string="${1}"
   local -r char="${2}"

   local last_character="${string: -1}"
   local new_string=''

   if [[ "${char}" == "${last_character}" ]]
   then
      new_string="${string::-1}"
   else
      new_string="${string}"
   fi

   # shellcheck disable=SC2034   
   __RESULT="${new_string}"
   
   return 0
}

