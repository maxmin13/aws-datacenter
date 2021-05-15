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
#
# AWS doesn't grant root access by default to EC2 instances. 
# This is an important security best practise. 
# Users are supposed to open a ssh connection using the secure key/pair to login 
# as ec2-user. 
# Users are supposed to use the sudo command as ec2-user to obtain 
# elevated privileges.
# Enabling direct root access to EC2 systems is a bad security practise which AWS 
# doesn't recommend. It creates vulnerabilities especially for systems which are 
# facing the Internet (see AWS documentation).
#
#===============================================================================

#===============================================================================
# Makes a SCP call to a server to upload a file. 
#
# Globals:
#  None
# Arguments:
# +private_key   -- Local private key.
# +server_ip     -- Server IP address.
# +ssh_port      -- Server SSH port.
# +user          -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +remote_dir    -- The remote directory where to upload the file.
# +file          -- The file to upload.
# Returns:      
#  None  
#===============================================================================
function scp_upload_file()
{
   if [[ $# -lt 6 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local private_key="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local user="${4}"
   local remote_dir="${5}"
   local file="${6}"

   scp -q \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i "${private_key}" \
       -P "${ssh_port}" \
       "${file}" \
       "${user}@${server_ip}:${remote_dir}"
 
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
# +user          -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +remote_dir    -- The remote directory where to upload the file.
# +files         -- A list of files to upload.
# Returns:      
#  None  
#===============================================================================
function scp_upload_files()
{
   if [[ $# -lt 6 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi

   local private_key="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local user="${4}"
   local remote_dir="${5}"
   local files=("${@:6:$#-5}")

   for file in "${files[@]}"
   do
      scp_upload_file "${private_key}" \
                      "${server_ip}" \
                      "${ssh_port}" \
                      "${user}" \
                      "${remote_dir}" \
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
# +private_key   -- Local private key.
# +server_ip     -- Server IP address.
# +ssh_port      -- Server SSH port.
# +user          -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +remote_dir    -- The remote directory where the file is.
# +file          -- The file to download.
# +local_dir     -- The local directory where to download the file.

# Returns:      
#  None  
#===============================================================================
function scp_download_file()
{
   if [[ $# -lt 7 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local private_key="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local user="${4}"
   local remote_dir="${5}"
   local file="${6}"
   local local_dir="${7}"
   
   scp -q \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i "${private_key}" \
       -P "${ssh_port}" \
       "${user}@${server_ip}:${remote_dir}/${file}" \
       "${local_dir}"
 
   return 0
}

#===============================================================================
# Runs a command on a server as non priviledged user using SSH.
# The function returns the remote command's return code.
#
# Globals:
#  None
# Arguments:
# +cmd           -- The command to execute on the server.
# +private_key   -- Local private key.
# +server_ip     -- Server IP address.
# +ssh_port      -- Server SSH port.
# +user          -- Name of the remote user that holds the access public-key. 
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

   local cmd="${1}"
   local private_key="${2}"
   local server_ip="${3}"
   local ssh_port="${4}"
   local user="${5}"
      
   if [[ "${cmd}" == *sudo* ]]
   then
     echo 'ERROR: command not allowed'
     exit 1
   fi     

   ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 -o BatchMode=yes -i "${private_key}" -p "${ssh_port}" -t "${user}"@"${server_ip}" "${cmd}"

   return $?   
}

#===============================================================================
# Runs a command on a server as a root using SSH.
# The program 'expect' has to be installed in the local system.
# The function returns the remote command's return code.
#
# AWS doesn't grant root access by default to EC2 instances. 
# This is an important security best practise. 
# Users are supposed to open a ssh connection using the secure key/pair to login 
# as ec2-user. 
# Users are supposed to use the sudo command as ec2-user to obtain 
# elevated privileges.
# Enabling direct root access to EC2 systems is a bad security practise which AWS 
# doesn't recommend. It creates vulnerabilities especially for systems which are 
# facing the Internet (see AWS documentation).
#
# Globals:
#  None
# Arguments:
# +cmd             -- The command to execute on the server.
# +private_key     -- Local private key.
# +server_ip       -- Server IP address.
# +ssh_port        -- Server SSH port.
# +user            -- Name of the remote user that holds the access public-key
#                     (ec2-user). 
# +password        -- The remote user's sudo pwd.
# Returns:      
#  None  
#===============================================================================
function ssh_run_remote_command_as_root()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      exit 1
   fi

   local cmd="${1}"
   
   if [[ "${cmd}" == *rm* ]]
   then
     echo 'ERROR: command not allowed as root'
     exit 1
   fi     
   
   local private_key="${2}"
   local server_ip="${3}"
   local ssh_port="${4}"
   local user="${5}"
   local password='-'
   
   if [[ "$#" -eq 6 ]]
   then
      password="${6}"
   fi  
  
   if [[ "${password}" == '-' ]]
   then 
      ## sudo without password.
      ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 -o BatchMode=yes -i "${private_key}" -p "${ssh_port}" -t "${user}"@"${server_ip}" "sudo ${cmd}" 
      
      exit_code=$?   
   else 
      ## sudo with password.
      ## Create a temporary authomated script in temp directory that handles the password without
      ## prompting for it.
      local expect_script="${TMP_DIR}"/ssh_run_remote_command.exp
      
      if [[ -f "${expect_script}" ]]
      then
         rm "${expect_script}"
      fi
      
      {  
         printf '%s\n' "#!/usr/bin/expect -f" 
         printf '%s\n' "set timeout -1" 
         printf '%s\n' "log_user 0"
         printf '%s\n' "spawn ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 -o BatchMode=yes -i ${private_key} -p ${ssh_port} -t ${user}@${server_ip} sudo ${cmd}"  
         printf '%s\n' "match_max 100000"
         printf '%s\n' "expect -exact \"\: \""
         printf '%s\n' "send -- \"${password}\r\""
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
# +user   -- Name of the user to log with into the server, must be the 
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
   local user="${4}"

   while ! ssh -q \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -o ConnectTimeout=60 \
               -o BatchMode=yes \
               -i "${private_key}" \
               -p "${ssh_port}" \
                  "${user}@${server_ip}" true; do
      echo -n . 
      sleep 3
   done;

   return 0
}

