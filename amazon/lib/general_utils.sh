#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: general_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Parses a string and escape the characters that are special characters for 
# 'sed' program.
# Replaces:
#          each '/' with '\/'
# Globals:
#  None
# Arguments:
# +str         -- The string to be parsed.
# Returns:      
#  the escaped string.  
#===============================================================================
function escape()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local str="${1}"
   local escaped_str
   
   # '/' to '\/'
   escaped_str="$(echo "${str}" | sed  -e 's/\//\\\//g')"
 
   echo "${escaped_str}"
}

#===============================================================================
# Makes the program sleep for a number of seconds.
# Globals:
#  None
        # Arguments:
# +seconds -- the number of seconds the program sleeps.
# Returns:      
#  None.  
#===============================================================================
function __wait()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local seconds="${1}"
   local count=0
   
   while [[ "${count}" -lt "${seconds}" ]]; do
      printf '.'
      sleep 1
      count=$((count+1))
   done
   
   printf '\n'
   
   return 0
}

#### TODO create a test script

## test escape https://github.com/joohoi/acme-dns
## Start tests: ##
##escaped="$(escape 'abc/efg')"
##if [[ "${escaped}" != 'abc\/efg' ]]
##then
##   echo "ERROR: escaping 'abc/efg'"
##   return 1 
##fi
## End tests. ##
