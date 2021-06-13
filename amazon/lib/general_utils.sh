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
      exit 1
   fi
   
   local str="${1}"
   local escaped_str
   
   # '/' to '\/'
   escaped_str="$(echo "${str}" | sed  -e 's/\//\\\//g')"
 
   echo "${escaped_str}"
}

## Start tests: ##
escaped="$(escape 'abc/efg')"
if [[ "${escaped}" != 'abc\/efg' ]]
then
   echo "ERROR: escaping 'abc/efg'"
   exit 1 
fi
## End tests. ##
