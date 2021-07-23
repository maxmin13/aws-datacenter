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
# +key_pair_file -- Local private key.
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
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local key_pair_file="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local user="${4}"
   local remote_dir="${5}"
   local file="${6}"

   scp -q \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i "${key_pair_file}" \
       -P "${ssh_port}" \
       "${file}" \
       "${user}@${server_ip}:${remote_dir}"
       
      local file_name
      file_name="$(echo "${file}" | awk -F "/" '{print $NF}')"
      echo "${file_name} uploaded."       
 
   return 0
}

#===============================================================================
# Uploads a group of files to a server with SCP. 
#
# Globals:
#  None
# Arguments:
# +key_pair_file -- Local private key.
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
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi

   local key_pair_file="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local user="${4}"
   local remote_dir="${5}"
   local files=("${@:6:$#-5}")

   for file in "${files[@]}"
   do
      scp_upload_file "${key_pair_file}" \
                      "${server_ip}" \
                      "${ssh_port}" \
                      "${user}" \
                      "${remote_dir}" \
                      "${file}"
   done
 
   return 0
}

#===============================================================================
# Makes a SCP call to a server to download a file. 
#
# Globals:
#  None
# Arguments:
# +key_pair_file -- Local private key.
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
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local key_pair_file="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local user="${4}"
   local remote_dir="${5}"
   local file="${6}"
   local local_dir="${7}"
   
   scp -q \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i "${key_pair_file}" \
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
# +key_pair_file   -- Local private key.
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
      return 1
   fi

   local cmd="${1}"
   local key_pair_file="${2}"
   local server_ip="${3}"
   local ssh_port="${4}"
   local user="${5}"
      
   if [[ "${cmd}" == *sudo* ]]
   then
     echo 'ERROR: command not allowed'
     return 1
   fi     

   ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 -o BatchMode=yes -i "${key_pair_file}" -p "${ssh_port}" -t "${user}"@"${server_ip}" "${cmd}"

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
# +key_pair_file     -- Local private key.
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
      return 1
   fi

   local cmd="${1}"
   
   if [[ "${cmd}" == *rm* ]]
   then
     echo 'ERROR: command not allowed as root'
     return 1
   fi     
   
   local key_pair_file="${2}"
   local server_ip="${3}"
   local ssh_port="${4}"
   local user="${5}"
   local exit_code
   local password='-'
   
   if [[ "$#" -eq 6 ]]
   then
      password="${6}"
   fi  
  
   if [[ "${password}" == '-' ]]
   then 
      ## sudo without password.
      ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 -o BatchMode=yes -i "${key_pair_file}" -p "${ssh_port}" -t "${user}"@"${server_ip}" "sudo ${cmd}" 
      
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
         printf '%s\n' "spawn ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 -o BatchMode=yes -i ${key_pair_file} -p ${ssh_port} -t ${user}@${server_ip} sudo ${cmd}"  
         printf '%s\n' "match_max 100000"
         printf '%s\n' "expect -exact \"\: \""
         printf '%s\n' "send -- \"${password}\r\""
         printf '%s\n' "expect eof"
         printf '%s\n' "puts \"\$expect_out(buffer)\""
         printf '%s\n' "lassign [wait] pid spawnid os_error_flag value"
         printf '%s\n' "exit \${value}"    
      } >> "${expect_script}"     
   
      chmod +x "${expect_script}"
      "${expect_script}" 
      exit_code=$?
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
      return 1
   fi

   local private_key="${1}"
   local server_ip="${2}"
   local ssh_port="${3}"
   local user="${4}"
   
   echo 'Waiting SSH started ...'

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
   echo .

   return 0
}

#===============================================================================
# Tryes to connect to each port passed to the method, if the connection is 
# successful returns the number of the port, if no connection succedes, returns
# an empty string. 
#
# Globals:
#  None
# Arguments:
# +key_pair_file -- Local private key.
# +server_ip     -- Server IP address.
# +user          -- Name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +ports         -- a list of port to be verified.
# Returns:      
#  None  
#===============================================================================
function get_ssh_port()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 1
   fi

   local key_pair_file="${1}"
   local server_ip="${2}"
   local user="${3}"

   shift
   shift
   shift

   for port in "$@"
   do
      set +e 
      ssh -q \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout='5' \
          -o BatchMode=yes \
          -i "${key_pair_file}" \
          -p "${port}" \
             "${user}@${server_ip}" 'exit 0'; 
       
      exit_code=$?
      set -e
      
      if [[ 0 -eq "${exit_code}" ]]
      then
         ssh_port="${port}"
         break
      fi
   done

   echo "${ssh_port}"
   
   return 0
}

#===============================================================================
# Creates a RSA key-pair and saves the private-key in the key_file file. The key
# is not protected by a passphrase.
#
# Globals:
#  None
# Arguments:
# +key_file   -- the file in which to store the pair.
# +email_add  -- email address.
# Returns:      
#  None  
#===============================================================================
function generate_keypair()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 1
   fi

   local key_file="${1}"
   local email_add="${2}"
      
   if [[ -f "${key_file}" ]]
   then
      echo 'ERROR: key-pair already exists.'
      return 1
   fi

   ssh-keygen -N '' -q -t rsa -b 4096 -C "${email_add}" -f "${key_file}"

   return 0
}

#===============================================================================
# Returns the public key associated with a key-pair.
#
# Globals:
#  None
# Arguments:
# +key_file   -- the file in which the pair stored.
# Returns:      
#  the public-key associated with the key-pair.  
#===============================================================================
function get_public_key()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 1
   fi

   local key_file="${1}"
   local public_key

   public_key="$(ssh-keygen -y -f "${key_file}")"
   
   echo "${public_key}"

   return 0
}

#===============================================================================
# Deletes the local key-pair file.
#
# Globals:
#  None
# Arguments:
# +key_file     -- the local key-pair file.
# Returns:      
#  None
#===============================================================================
function delete_keypair()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local key_file="${1}"

   # Delete the local private-key.
   rm -f "${key_file:?}"
   rm -f "${key_file:?}.pub"

   # Delete the key-pair on EC2.
   # TODO when created with Cloud Init, the key is not there, where is it ???
   # aws ec2 delete-key-pair --key-name "${keypair_nm}"

   return 0
}

#===============================================================================
# Returns the path to a key-pair file is saved.
#
# Globals:
#  None
# Arguments:
# +keypair_nm     -- the key-pair name.
# +keypair_dir    -- the local directory where the key-pair is stored.
# Returns:      
#  the key-pair's path.
#===============================================================================
function get_keypair_file_path()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local keypair_nm="${1}"
   local keypair_dir="${2}"
   local keypair_file="${keypair_dir}"/"${keypair_nm}".pem
   
   echo "${keypair_file}"
  
   return 0
}

