#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: httpd_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Creates an Apache Web Server Virtual Host configuration file that can be 
# loaded at start up by Apache 'httpd' main configuration file.
# 
# Ex: to create a virtual host for phpmyadmin:
#
#  create_virtualhost_configuration_file './virtual.conf' '127,0.0.1' '8090' 'admin.maxmin.it' '/var/www/html' 'phpmyadmin.maxmin.it' 
#  add_alias_to_virtualhost './virtual.conf' 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' 'phpmyadmin' 
#  remove_alias_from_virtualhost './virtual.conf' 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' 
# 
#  <VirtualHost 127,0.0.1:8090>
#     ServerName admin.maxmin.it
#     DocumentRoot /var/www/html/phpmyadmin.maxmin.it/public_html
#     Alias /phpmyadmin /var/www/html/phpmyadmin.maxmin.it/public_html/phpmyadmin
#  </VirtualHost>
#  <Directory /var/www/html/phpmyadmin.maxmin.it/public_html>
#     Require all granted
#  </Directory>
#
# Ex: to create a load balancer virtual host for the heal-check of an instance:
#
#  create_virtualhost_configuration_file './virtual.conf' '127,0.0.1' '8090' 'admin.maxmin.it' '/var/www/html' 'elb.maxmin.it' 
#  add_loadbalancer_rule_to_virtualhost './virtual.conf' 'elb.htm' '/var/www/html' 'elb.maxmin.it' 
#  remove_loadbalancer_rule_from_virtualhost './virtual.conf' 'elb.htm' '/var/www/html' 'elb.maxmin.it'  
#
#  <VirtualHost 127,0.0.1:8090>
#     ServerName admin.maxmin.it
#     DocumentRoot /var/www/html/elb.maxmin.it/public_html
#     RewriteEngine On
#     RewriteCond %{HTTP_USER_AGENT} ^ELB-HealthChecker\/(.*)$
#     RewriteRule elb.htm /var/www/html/elb.maxmin.it/public_html/elb.htm [L]
#  </VirtualHost>
#  <Directory /var/www/html/elb.maxmin.it/public_html>
#     Require all granted
#  </Directory>
#
# Ex: to create a Certbot virtual host on port 80:
#
#  create_virtualhost_configuration_file './virtual.conf' '*' '80' 'example.com' '/var/www/html' 
#  add_server_alias_to_virtualhost './virtual.conf' 'www.example.com'
#  remove_server_alias_from_virtualhost './virtual.conf' 'www.example.com' 
#
#  <VirtualHost *:80>
#     ServerName example.com
#     DocumentRoot /var/www/html
#     ServerAlias www.example.com
#  </VirtualHost>
#
#===============================================================================

#===============================================================================
# Creates the virtualhost configuration file, with <VirtualHost> element,
# ServerName and DocumentRoot directive.
#
#  <VirtualHost 127.0.0.1:8090>
#     ServerName webphp.maxmin.it
#     DocumentRoot /var/www/html/webphp1.maxmin.it/public_html
#  </VirtualHost>
#
# Globals:
#  None
# Arguments:
# +virtual_host_file  -- The path to the virtual host configuration file.
# +address            -- The server IP address to which the virtual host 
#                        responds.
# +port               -- The server IP port to which the virtual host responds. 
# +domain             -- The request domain to which the virtual host responds
#                        (ServerName directive).
# +base_doc_root      -- The Apache server base document root, usually
#                        /var/www/http, from which the DocumentRoot directive
#                        is built.
# +doc_root_id        -- String appended to the base document root to obtain the
#                        full path to the directory with the content served by the 
#                        virtual host, eg:
#                        /var/www/html/webphp1.maxmin.it/public_html
# Returns:      
#  None  
#===============================================================================
function create_virtualhost_configuration_file()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local address="${2}"
   local port="${3}"
   local domain="${4}"
   local base_doc_root="${5}" 
   local doc_root_id='-' 
   
   if [[ $# -eq 6 ]]
   then
      doc_root_id="${6}"
      __add_virtualhost_element "${virtual_host_file}" "${address}" "${port}" "${domain}" "${base_doc_root}" "${doc_root_id}"
   else
      __add_virtualhost_element "${virtual_host_file}" "${address}" "${port}" "${domain}" "${base_doc_root}" 
   fi   
   
   return 0
}

#===============================================================================
# Add a ServerAlias directive to the <VirtualHost>  element.
# The ServerAlias directive sets the alternate names for a host, for use with 
# name-based virtual hosts.
#
# Eg: ServerAlias www.example.com
#
# Globals:
#  None
# Arguments:
# +virtual_host_file  -- The path to the virtual host configuration file.
# +server_alias_nm    -- The server alias name.
# Returns:      
#  None  
#===============================================================================
function add_server_alias_to_virtualhost()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local server_alias_nm="${2}"

   __add_server_alias_directive "${virtual_host_file}" "${server_alias_nm}"
 
   return 0
}

function remove_server_alias_from_virtualhost()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local server_alias_nm="${2}"
   
   __remove_directive "${virtual_host_file}" "ServerAlias ${server_alias_nm}"  
   
   return 0
} 

#===============================================================================
# Add an Alias directive to the <VirtualHost>  element.
# The Alias directive allows documents to be stored in the local filesystem 
# other than under the DocumentRoot.
#
# Eg: Alias /phpmyadmin /var/www/html/phpmyadmin.maxmin.it/public_html/phpmyadmin
#
# Globals:
#  None
# Arguments:
# +virtual_host_file  -- The path to the virtual host configuration file.
# +alias_nm           -- The alias name.
# +base_doc_root      -- The Apache server base document root, usually
#                        /var/www/http, from which the DocumentRoot directive
#                        is built.
# +doc_root_id        -- String appended to the base document root to obtain the
#                        full path to the directory with the content served by the 
#                        virtual host, eg:
#                        /var/www/html/webphp1.maxmin.it/public_html
# +aliased_nm         -- The resource referred by the alias. If the aliased_nm 
#                        parameter is not passed, the aliased resource name is
#                        supposed equal to the alias name.
# Returns:      
#  None  
#===============================================================================
function add_alias_to_virtualhost()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local alias_nm="${2}"
   local base_doc_root="${3}"
   local doc_root_id="${4}"
   local aliased_nm="${5}"
   
   #### './virtual.conf' 'www.example.com' '/var/www/html' 
      
   __add_alias_directive "${virtual_host_file}" "${alias_nm}" "${base_doc_root}" "${doc_root_id}" "${aliased_nm}"  
   __add_directory_element "${virtual_host_file}" "${base_doc_root}" "${doc_root_id}"  
 
   return 0
}

function remove_alias_from_virtualhost()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local alias_nm="${2}"
   local base_doc_root="${3}"
   local doc_root_id="${4}"
   
   __remove_directive "${virtual_host_file}" "Alias /${alias_nm}"  
   __remove_directory_element "${virtual_host_file}" "${base_doc_root}" "${doc_root_id}"  
   
   return 0
} 

#===============================================================================
# Add a mod_rewrite codition and rule to the <VirtualHost> element, identifying
# a heart-beat request coming from the load balancer.
#
# Eg:
#
#  RewriteEngine On
#  RewriteCond  "%{HTTP_USER_AGENT}" "^ELB-HealthChecker\/(.*)$"
#  RewriteRule  "/elb.htm" "/var/www/html/elb.maxmin.it/public_html/elb.htm" [L]
#
# Globals:
#  None
# Arguments:
# +virtual_host_file  -- The path to the virtual host configuration file.
# +alias_nm           -- The alias name.
# +base_doc_root      -- The Apache server base document root, usually
#                        /var/www/http, from which the DocumentRoot directive
#                        is built.
# +doc_root_id        -- String appended to the base document root to obtain the
#                        full path to the directory with the content served by 
#                        the virtual host, eg:
#                        /var/www/html/webphp1.maxmin.it/public_html
# Returns:      
#  None  
#===============================================================================
function add_loadbalancer_rule_to_virtualhost()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local alias="${2}"
   local base_doc_root="${3}"
   local doc_root_id="${4}"
   
   # For mod_rewrite, you need to escape the space and forward slash in the regular expression pattern:
   # the regex of: ^ELB-HealthChecker/1.0$ would be: ^ELB-HealthChecker\\\\/(.*)$ 
                              
   substitution="${base_doc_root}/${doc_root_id}/public_html/${alias}"
  
   __add_rewrite_engine_directive "${virtual_host_file}"
   ##__add_log_level_directive "${virtual_host_file}"
   __add_rewrite_cond_directive  "${virtual_host_file}" '%{HTTP_USER_AGENT}'  '^ELB-HealthChecker\\\\/(.*)$'
   __add_rewrite_rule_directive "${virtual_host_file}" "${alias}" "${substitution}" 
   __add_directory_element "${virtual_host_file}" "${base_doc_root}" "${doc_root_id}"                                
 
   return 0
}

function remove_loadbalancer_rule_from_virtualhost()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local alias="${2}"
   local base_doc_root="${3}"
   local doc_root_id="${4}"
   
   # RewriteCond directive
   __remove_directive "${virtual_host_file}" '%{HTTP_USER_AGENT}'  
   
   # RewriteRule directive
   __remove_directive "${virtual_host_file}" "RewriteRule ${alias}" 
   
   # RewriteEngine directive
   __remove_directive "${virtual_host_file}" 'RewriteEngine'
    
   # LogLevel directive
   __remove_directive "${virtual_host_file}" 'LogLevel' 
   __remove_directory_element "${virtual_host_file}" "${base_doc_root}" "${doc_root_id}"                             
 
   return 0
}

function __add_virtualhost_element()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi

   local virtual_host_file="${1}"
   local address="${2}"
   local port="${3}"
   local domain="${4}"
   local base_doc_root="${5}" 
   local doc_root_id='-' 
   local virtual_host_element   
   
   if [[ $# -eq 6 ]]
   then
      doc_root_id="${6}"
   
      cat <<-EOF > "${virtual_host_file}"
	<VirtualHost SEDip_addressSED:SEDip_portSED>
	   ServerName SEDrequest_domainSED
	   DocumentRoot SEDbase_doc_root_dirSED/SEDdoc_root_idSED/public_html
	</VirtualHost>
	EOF
   else
      cat <<-EOF > "${virtual_host_file}"
	<VirtualHost SEDip_addressSED:SEDip_portSED>
	   ServerName SEDrequest_domainSED
	   DocumentRoot SEDbase_doc_root_dirSED
	</VirtualHost>
	EOF
   fi

   virtual_host_element="$(sed -e "s/SEDip_addressSED/${address}/g" \
               -e "s/SEDip_portSED/${port}/g" \
               -e "s/SEDrequest_domainSED/${domain}/g" \
               -e "s/SEDbase_doc_root_dirSED/$(escape "${base_doc_root}")/g" \
               -e "s/SEDdoc_root_idSED/$(escape "${doc_root_id}")/g" \
                  "${virtual_host_file}")" 
                                                 
   echo "${virtual_host_element}" > "${virtual_host_file}"
   
   return 0
}

function __add_directory_element()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}" 
   local directory_element 
   
   directory_element="$(__build_directory_element "${base_doc_root}" "${doc_root_id}")"
   printf '%s\n' "${directory_element}" >> "${virtual_host_file}"                                   
 
   return 0
}

function __remove_directory_element()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}"
   local directory_element

   sed -i "/<Directory $(escape "${base_doc_root}"/"${doc_root_id}"/public_html)/,/<\/Directory>/d" "${virtual_host_file}"

   return 0
}

function __add_rewrite_rule_directive()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}" 
   local pattern="${2}"
   local substitution="${3}"    
   local rewrite_rule_directive 
   
   # Add the directive before the </VirtualHost> element.
   rewrite_rule_directive="$(__build_rewrite_rule_directive "${pattern}" "${substitution}")"
   sed -i "/^<\/VirtualHost>/i ${rewrite_rule_directive}" "${virtual_host_file}"
   sed -i "s/^RewriteRule/   RewriteRule/g" "${virtual_host_file}"     
                                          
   return 0   
}

# Must be called before adding the rewrite rule directive
function __add_rewrite_cond_directive()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local test_string="${2}"
   local cond_pattern="${3}"     
   local rewrite_cond_directive 
   
   # Add the directive before the </VirtualHost> element.
   rewrite_cond_directive="$(__build_rewrite_cond_directive "${test_string}" "${cond_pattern}")"
   sed -i "/^<\/VirtualHost>/i ${rewrite_cond_directive}" "${virtual_host_file}"
   sed -i "s/^RewriteCond/   RewriteCond/g" "${virtual_host_file}"
                                               
   return 0  
}

# Must be called before the other directives
function __add_rewrite_engine_directive()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi

   local virtual_host_file="${1}"       
   
   # Add the directive before the </VirtualHost> element.
   sed -i "/^<\/VirtualHost>/i RewriteEngine On" "${virtual_host_file}"
   sed -i "s/^RewriteEngine/   RewriteEngine/g" "${virtual_host_file}"
                                               
   return 0  
}

function __add_log_level_directive()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi

   local virtual_host_file="${1}"       
   
   # Add the directive before the </VirtualHost> element.
   sed -i "/^<\/VirtualHost>/i LogLevel alert rewrite:trace8" "${virtual_host_file}"
   sed -i "s/^LogLevel/   LogLevel/g" "${virtual_host_file}"
                                               
   return 0  
}

# The ServerAlias directive sets the alternate names for a host, for use with name-based virtual 
# hosts.
function __add_server_alias_directive()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local server_alias_nm="${2}"      
   local directive
   
   directive="$(__build_server_alias_directive "${server_alias_nm}")"
     
   # Add the ServerAlias directive before the </VirtualHost> element.
   sed -i "/^<\/VirtualHost>/i ${directive}" "${virtual_host_file}"
   sed -i "s/^ServerAlias/   ServerAlias/g" "${virtual_host_file}"
                                                
   return 0
}

# The Alias directive allows documents to be stored in the local filesystem other than under the 
# DocumentRoot. 
function __add_alias_directive()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local alias_nm="${2}"
   local base_doc_root="${3}"
   local doc_root_id="${4}"
   local aliased_nm="${5}"      
   local directive
   
   directive="$(__build_alias_directive "${alias_nm}" \
                                        "${base_doc_root}" \
                                        "${doc_root_id}" \
                                        "${aliased_nm}")"
     
   # Add the Alias directive before the </VirtualHost> element.
   sed -i "/^<\/VirtualHost>/i ${directive}" "${virtual_host_file}"
   sed -i "s/^Alias/   Alias/g" "${virtual_host_file}"
                                                
   return 0
}

# Remove the line containing the regex.
function __remove_directive()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local virtual_host_file="${1}"
   local regex="${2}"
                                               
   sed -i "/$(escape "${regex}")/d" "${virtual_host_file}"
   
   return 0
}

function __build_directory_element()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi

   local base_doc_root="${1}"
   local doc_root_id="${2}" 
   local template='<Directory SEDbase_doc_root_dirSED/SEDdoc_root_idSED/public_html>\n   Require all granted\n</Directory>\n'

   directory_element="$(printf '%b\n' "${template}" \
                        | sed -e "s/SEDdoc_root_idSED/${doc_root_id}/g" \
                              -e "s/SEDbase_doc_root_dirSED/$(escape "${base_doc_root}")/g")"               

   echo "${directory_element}"
   
   return 0
}

function __build_server_alias_directive()
{
   if [[ $# -lt 1 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local server_alias_nm="${1}"
   local template='ServerAlias SEDpar1SED'
   local directive 
  
   directive="$(__build_directive "${template}" "${server_alias_nm}")"           
   echo "${directive}"

   return 0                                                        
}

function __build_alias_directive()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias_nm="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}"
   local aliased_nm="${4}"
   local template='Alias /SEDpar1SED SEDpar2SED/SEDpar3SED/public_html/SEDpar4SED'
   local directive 
  
   directive="$(__build_directive "${template}" \
                                  "${alias_nm}" \
                                  "${base_doc_root}" \
                                  "${doc_root_id}" \
                                  "${aliased_nm}")"           
   echo "${directive}"

   return 0                                                        
}

function __build_rewrite_cond_directive()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local test_string="${1}"
   local cond_pattern="${2}"
   local template='RewriteCond SEDpar1SED SEDpar2SED'
   local directive  
 
   directive="$(__build_directive "${template}" \
                                  "${test_string}" \
                                  "${cond_pattern}")"
   echo "${directive}"

   return 0
}

function __build_rewrite_rule_directive()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local pattern="${1}"
   local substitution="${2}"
   local template='RewriteRule SEDpar1SED SEDpar2SED [L]'
   local directive

   directive="$(__build_directive "${template}" \
                                  "${pattern}" \
                                  "${substitution}")"
   echo "${directive}"

   return 0
}

# Builds a httpd directive, given a template in any the following forms:
#  RewriteRule SEDpar1SED SEDpar2SED [L]
#  RewriteCond SEDpar1SED SEDpar2SED
#  Alias SEDpar1SED SEDpar2SED/SEDpar3SED/public_html/SEDpar4SED
function __build_directive()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local directive_template="${1}"
   local directive_param par
   local count=1
 
   shift
   for par in "$@"
   do
      # Substitute each pamameter in the template directive.
      directive_param="$(echo 'SEDpar<i>SED' | sed -e "s/<i>/$count/g")"  
      directive_template=${directive_template//${directive_param}/$(escape ${par})}  
      ((count++))
   done
                                                           
   echo "${directive_template}"  
   
   return 0                                                       
}

#__build_directive 'Alias /SEDpar1SED SEDpar2SED/SEDpar3SED/public_html/SEDpar4SED' "webphp" "/var/www/html" "webphp.maxmin.it" "webphp"
#__build_directive 'Alias /SEDpar1SED SEDpar2SED/SEDpar3SED/public_html/SEDpar4SED' "index.php" "/var/www/html" "webphp.maxmin.it" "index.php"

#__build_rewrite_cond_directive "%{HTTP_USER_AGENT}"  "^ELB-HealthChecker/(.*)$"
#__build_rewrite_rule_directive "/elb.htm" "/var/www/html" "/elb.maxmin.it"
#__build_alias_directive 'elb.htm' '/var/www/html' 'elb.maxmin.it' 'elb.htm'
#__build_alias_directive 'webphp' '/var/www/html' 'elb.maxmin.it' 'index.php'
#__build_server_alias_directive 'www.example.com'
#__build_directory_element '/var/www/html' 'elb.maxmin.it'

#__add_virtualhost_element './virtual.conf' '127.0.0.1' '8090' 'admin.maxmin.it' '/var/www/html' 'admin.maxmin.it'  

#__add_alias_directive './virtual.conf' 'elb.htm' '/var/www/html' 'elb.maxmin.it' 'elb.htm'  
#__remove_directive 'elb.htm' './virtual.conf'
#__add_alias_directive './virtual.conf' 'webphp' '/var/www/html' 'elb.maxmin.it'  'index.php' 
#__remove_directive './virtual.conf' 'webphp' 
#__add_server_alias_directive './virtual.conf' 'www.example.com'
#__remove_directive './virtual.conf' 'www.example.com' 

#__add_directory_element './virtual.conf' '/var/www/html' 'elb.maxmin.it' 
#__remove_directory_element './virtual.conf' '/var/www/html' 'elb.maxmin.it' 

#__add_rewrite_engine_directive './virtual.conf'
#__add_rewrite_cond_directive './virtual.conf' "%{HTTP_USER_AGENT}" "^ELB-HealthChecker/(.*)$" 
#__add_rewrite_rule_directive './virtual.conf' "%{HTTP_USER_AGENT}" "^ELB-HealthChecker/(.*)$"  
#
#  create_virtualhost_configuration_file './virtual.conf' '127,0.0.1' '8090' 'admin.maxmin.it' '/var/www/html' 'phpmyadmin.maxmin.it' 
#  add_alias_to_virtualhost './virtual.conf' 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' 'phpmyadmin' 
#  remove_alias_from_virtualhost './virtual.conf' 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' 
#
#  create_virtualhost_configuration_file './virtual.conf' '*' '80' 'example.com' '/var/www/html' 
#  add_server_alias_to_virtualhost './virtual.conf' 'www.example.com'
#  remove_server_alias_from_virtualhost './virtual.conf' 'www.example.com'

