#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: ssh_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Makes a SCP call to a server to upload a file. 
#
# Globals:
#  None
# Arguments:
# +file          -- The file to upload.
# +private_key   -- Local private key.
# +server_ip     -- Server IP address.
# +ssh_port      -- Server SSH port.
# +server_user   -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# Returns:      
#  None  
#===============================================================================
function scp_upload_file()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local private_key="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local server_user="${4}"
   local file="${5}"
   
   scp -q \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i "${private_key}" \
       -P "${ssh_port}" \
       "${file}" \
       "${server_user}@${server_ip}":
 
   return 0
}

#===============================================================================
# Uploads a group of files to a server with SCP. 
#
# Globals:
#  None
# Arguments:
# +private_key   -- Local private key.
# +server_ip     -- Server IP address.
# +ssh_port      -- Server SSH port.
# +server_user   -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +files         -- A list of files to upload.
# Returns:      
#  None  
#===============================================================================
function scp_upload_files()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi

   local private_key="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local server_user="${4}"
   local files=("${@:5:$#-4}")
   
   for file in "${files[@]}"
   do
      scp_upload_file "${private_key}" \
                      "${server_ip}" \
                      "${ssh_port}" \
                      "${server_user}" \
                      "${file}"
      local file_name
      file_name="$(echo "${file}" | awk -F "/" '{print $NF}')"
      echo "${file_name} uploaded"
   done
 
   return 0
}

#===============================================================================
# Makes a SCP call to a server to download a file. 
#
# Globals:
#  None
# Arguments:
# +file          -- The file to download.
# +private_key   -- Local private key.
# +server_ip     -- Server IP address.
# +ssh_port      -- Server SSH port.
# +server_user   -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +download_dir  -- The local directory where to download the file.
# Returns:      
#  None  
#===============================================================================
function scp_download_file()
{
   if [[ $# -lt 6 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local private_key="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local server_user="${4}"
   local file="${5}"
   local download_dir="${6}"

   scp -q \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i "${private_key}" \
       -P "${ssh_port}" \
       "${server_user}@${server_ip}:${file}" \
       "${download_dir}"
 
   return 0
}

#===============================================================================
# Runs a command on a server as a priviledged user using SSH.
# The program 'expect' has to be installed in the local system.
# If the parameter 'server_pwd' is not passed, the remote user is supposed 
# without password and the user's 'sudo' command is supposed without 
# password.
# The function returns the return code of the remote commomand.
#
# Globals:
#  None
# Arguments:
# +server_cmd    -- The command to execute on the server.
# +private_key   -- Local private key.
# +server_ip     -- Server IP address.
# +ssh_port      -- Server SSH port.
# +server_user   -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +server_pwd    -- The user's password.
# Returns:      
#  None  
#===============================================================================
function ssh_run_remote_command()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      exit 1
   fi

   local server_cmd="${1}"
   local private_key="${2}"
   local server_ip="${3}"
   local ssh_port="${4}"
   local server_user="${5}"
   local server_pwd='-'
   
   if [[ "$#" -eq 6 ]]
   then
      server_pwd="${6}"
   fi  
  
   if [[ "${server_pwd}" == '-' ]]
   then 
      # The remote user has no password and the sudo command doesn't have password: 
      # the command is run with sudo prepended.
      ssh -q \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout=60 \
          -o BatchMode=yes \
          -i "${private_key}" \
          -p "${ssh_port}" \
          -t "${server_user}@${server_ip}" \
             "sudo ${server_cmd}"
      exit_code=$?   
   else
      # The remote user has a password and the sudo command needs a password:
      # establish a SSH session, switch to root, run the command.     
      local expect_script="${TMP_DIR}"/ssh_run_remote_command.exp
      
      {    
         printf '%s\n' "#!/usr/bin/expect -f" 
         printf '%s\n' "set timeout -1" 
         printf '%s\n' "log_user 0"
         printf '%s\n' "spawn ssh -i ${private_key} -p ${ssh_port} -o ConnectTimeout=60 -o BatchMode=yes -o StrictHostKeyChecking=no ${server_user}@${server_ip}" 
         printf '%s\n' "sleep 3" 
         printf '%s\n' "send \"sudo su\r\"" 
         printf '%s\n' "expect -exact \":\"" 
         printf '%s\n' "send \"${server_pwd}\r\""      
         printf '%s\n' "expect -exact \"]#\"" 
         printf '%s\n' "send \"${server_cmd}\r\"" 
         printf '%s\n' "send \"exit\r\""
         printf '%s\n' "send \"exit\r\""
         printf '%s\n' "expect eof" 
         printf '%s\n' "lassign [wait] pid spawnid os_error_flag value"
         printf '%s\n' "send_user \${value}"                 
      } >> "${expect_script}"     
   
      chmod +x "${expect_script}"
      exit_code="$(${expect_script})" 
      rm -f "${expect_script}"     
   fi 

   return "${exit_code}"   
}

#===============================================================================
# Waits until SSH is available on the remote server, then returns. 
#
# Globals:
#  None
# Arguments:
# +private_key   -- Local private key.
# +server_ip     -- Server IP address.
# +ssh_port      -- Server SSH port.
# +server_user   -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# Returns:      
#  None  
#===============================================================================
function wait_ssh_started()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      exit 1
   fi

   local private_key="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local server_user="${4}"

   while ! ssh -q \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -o ConnectTimeout=60 \
               -o BatchMode=yes \
               -i "${private_key}" \
               -p "${ssh_port}" \
                  "${server_user}@${server_ip}" true; do
      echo -n . 
      sleep 3
   done;

   return 0
}

