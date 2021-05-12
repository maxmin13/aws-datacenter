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
# Ex:
#
#  create_virtualhost_configuration_file '127,0.0.1' '8090' 'webphp.maxmin.it' '/var/www/html' 'webphp1.maxmin.it' './virtual.conf'
#  add_alias_to_virtualhost 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'
#  remove_alias_from_virtualhost 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'
# 
#  <VirtualHost 127.0.0.1:8090>
#     ServerName admin.maxmin.it
#     DocumentRoot /var/www/html
#     Alias /phpmyadmin /var/www/html/phpmyadmin.maxmin.it/public_html/phpmyadmin
#  </VirtualHost>
# 
#  <Directory /var/www/html/phpmyadmin.maxmin.it/public_html>
#     Require all granted
#  </Directory>
#
# Ex:
#
#  create_virtualhost_configuration_file '127,0.0.1' '8090' 'wephp.maxmin.it' '/var/www/html' 'webphp2.maxmin.it' './virtual.conf'
#  add_loadbalancer_rule_to_virtualhost 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#  remove_loadbalancer_rule_from_virtualhost 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#
#  <VirtualHost 127.0.0.1:8090>
#     ServerName admin.maxmin.it
#     DocumentRoot /var/www/html/elb.maxmin.it/public_html
#     RewriteEngine On
#     RewriteCond  "%{HTTP_USER_AGENT}" "^ELB-HealthChecker\/(.*)$"
#     RewriteRule  "/elb.htm" "/var/www/html/elb.maxmin.it/public_html/elb.htm" [L]
#  </VirtualHost>
# 
#  <Directory /var/www/html/elb.maxmin.it/public_html>
#     Require all granted
#  </Directory>
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
# +virtual_host_file  -- The path to the virtual host configuration file.
# Returns:      
#  None  
#===============================================================================
function create_virtualhost_configuration_file()
{
   if [[ $# -lt 6 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local address="${1}"
   local port="${2}"
   local domain="${3}"
   local base_doc_root="${4}" 
   local doc_root_id="${5}"    
   local virtual_host_file="${6}"
      
   __add_virtualhost_element "${address}" "${port}" "${domain}" "${base_doc_root}" "${doc_root_id}" "${virtual_host_file}"
   
   return 0
}

#===============================================================================
# Add an Alias directive to the <VirtualHost>  element.
#
# Eg: Alias /phpmyadmin /var/www/html/phpmyadmin.maxmin.it/public_html/phpmyadmin
#
# Globals:
#  None
# Arguments:
# +alias_nm           -- The alias name.
# +base_doc_root      -- The Apache server base document root, usually
#                        /var/www/http, from which the DocumentRoot directive
#                        is built.
# +doc_root_id        -- String appended to the base document root to obtain the
#                        full path to the directory with the content served by the 
#                        virtual host, eg:
#                        /var/www/html/webphp1.maxmin.it/public_html
# +virtual_host_file  -- The path to the virtual host configuration file.
# +aliased_nm         -- The resource referred by the alias. If the aliased_nm 
#                        parameter is not passed, the aliased resource name is
#                        supposed equal to the alias name.
# Returns:      
#  None  
#===============================================================================
function add_alias_to_virtualhost()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias_nm="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}"
   local virtual_host_file="${4}"
   
   if [[ $# -eq 4 ]]
   then
       __add_alias_directive "${alias_nm}" "${base_doc_root}" "${doc_root_id}" "${virtual_host_file}"
   elif [[ $# -eq 5 ]]  
   then
      # The alias name is different from the aliased resource.
      aliased_nm="${5}"
      __add_alias_directive "${alias_nm}" "${base_doc_root}" "${doc_root_id}" "${virtual_host_file}" "${aliased_nm}"
   fi   
   
   __add_directory_element "${base_doc_root}" "${doc_root_id}" "${virtual_host_file}" 
 
   return 0
}

function remove_alias_from_virtualhost()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias_nm="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}"
   local virtual_host_file="${4}"
   
   __remove_directive "Alias /${alias_nm}" "${virtual_host_file}" 
   __remove_directory_element "${base_doc_root}" "${doc_root_id}" "${virtual_host_file}" 
   
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
# +alias_nm           -- The alias name.
# +base_doc_root      -- The Apache server base document root, usually
#                        /var/www/http, from which the DocumentRoot directive
#                        is built.
# +doc_root_id        -- String appended to the base document root to obtain the
#                        full path to the directory with the content served by 
#                        the virtual host, eg:
#                        /var/www/html/webphp1.maxmin.it/public_html
# +virtual_host_file  -- The path to the virtual host configuration file.
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
   
   local alias="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}"
   local virtual_host_file="${4}"

   # For mod_rewrite, you need to escape the space and forward slash in the regular expression pattern:
   # the regex of: ^ELB-HealthChecker/1.0$ would be: ^ELB-HealthChecker\\\\/(.*)$ 
                              
   substitution="${base_doc_root}/${doc_root_id}/public_html/${alias}"
  
   __add_rewrite_engine_directive "${virtual_host_file}"
   ##__add_log_level_directive "${virtual_host_file}"
   __add_rewrite_cond_directive '%{HTTP_USER_AGENT}'  '^ELB-HealthChecker\\\\/(.*)$' "${virtual_host_file}"
   __add_rewrite_rule_directive "${alias}" "${substitution}" "${virtual_host_file}"
   __add_directory_element "${base_doc_root}" "${doc_root_id}" "${virtual_host_file}"                                 
 
   return 0
}

function remove_loadbalancer_rule_from_virtualhost()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}"
   local virtual_host_file="${4}"

   # RewriteCond directive
   __remove_directive '%{HTTP_USER_AGENT}' "${virtual_host_file}" 
   # RewriteRule directive
   __remove_directive "RewriteRule ${alias}" "${virtual_host_file}"
   # RewriteEngine directive
   __remove_directive 'RewriteEngine' "${virtual_host_file}"
   # LogLevel directive
   __remove_directive 'LogLevel' "${virtual_host_file}"
   __remove_directory_element "${base_doc_root}" "${doc_root_id}" "${virtual_host_file}"                            
 
   return 0
}

function __add_virtualhost_element()
{
   if [[ $# -lt 6 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi

   local address="${1}"
   local port="${2}"
   local domain="${3}"
   local base_doc_root="${4}" 
   local doc_root_id="${5}"    
   local virtual_host_file="${6}"
   local virtual_host_element
   
   cat <<-EOF > "${virtual_host_file}"
	<VirtualHost SEDip_addressSED:SEDip_portSED>
	   ServerName SEDrequest_domainSED
	   DocumentRoot SEDbase_doc_root_dirSED/SEDdoc_root_idSED/public_html
	</VirtualHost>
	EOF

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
   
   local base_doc_root="${1}"
   local doc_root_id="${2}" 
   local virtual_host_file="${3}"   
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
   
   local base_doc_root="${1}"
   local doc_root_id="${2}"
   local virtual_host_file="${3}" 
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
   
   local pattern="${1}"
   local substitution="${2}"
   local virtual_host_file="${3}"       
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
   
   local test_string="${1}"
   local cond_pattern="${2}"
   local virtual_host_file="${3}"       
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

function __add_alias_directive()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias_nm="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}"
   local virtual_host_file="${4}"
   local aliased_nm            
   local directive
   
   if [[ $# -eq 4 ]]
   then
      directive="$(__build_alias_directive "${alias_nm}" "${base_doc_root}" "${doc_root_id}")"
   elif [[ $# -eq 5 ]]  
   then
      # The alias name is different from the aliased resource.
      aliased_nm="${5}"
      directive="$(__build_alias_directive "${alias_nm}" "${base_doc_root}" "${doc_root_id}" "${aliased_nm}")"
   fi
     
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
   
   local regex="${1}"
   local virtual_host_file="${2}"
                                              
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
   local directory_element_template='<Directory SEDbase_doc_root_dirSED/SEDdoc_root_idSED/public_html>\n   Require all granted\n</Directory>\n'

   directory_element="$(printf '%b\n' "${directory_element_template}" \
                        | sed -e "s/SEDdoc_root_idSED/${doc_root_id}/g" \
                              -e "s/SEDbase_doc_root_dirSED/$(escape "${base_doc_root}")/g")"               

   echo "${directory_element}"
   
   return 0
}

function __build_alias_directive()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias_nm="${1}"
   local base_doc_root="${2}"
   local doc_root_id="${3}"
   local aliased_nm
   local directive 
  
   if [[ $# -eq 3 ]]
   then
      # The alias name is the same as the aliased resource.
      directive="$(__build_directive 'false' 'Alias /SEDpar1SED SEDpar2SED/SEDpar3SED/public_html/SEDpar1SED' "${alias_nm}" "${base_doc_root}" "${doc_root_id}")"
   elif [[ $# -eq 4 ]]  
   then
      # The alias name is different from the aliased resource.
      aliased_nm="${4}"
      directive="$(__build_directive 'false' 'Alias /SEDpar1SED SEDpar2SED/SEDpar3SED/public_html/SEDpar4SED' "${alias_nm}" "${base_doc_root}" "${doc_root_id}" "${aliased_nm}")" 
   fi                
     
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
   local directive  
 
   directive="$(__build_directive 'true' 'RewriteCond SEDpar1SED SEDpar2SED' "${test_string}" "${cond_pattern}")"
   
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
   local directive

   directive="$(__build_directive 'true' 'RewriteRule SEDpar1SED SEDpar2SED [L]' "${pattern}" "${substitution}")"
   
   echo "${directive}"

   return 0
}

# Builds a httpd directive, given a template in any the following forms:
#  RewriteRule SEDpar1SED SEDpar2SED [L]
#  RewriteCond SEDpar1SED SEDpar2SED
#  Alias SEDpar1SED SEDpar2SED/SEDpar3SED/public_html/SEDpar4SED
function __build_directive()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local directive_template="${2}"
   local directive_param par
   local count=1

   shift 
   shift
   for par in "$@"
   do
      # Substitute each pamameter in the template directive.
      directive_param="$(echo 'SEDpar<i>SED' | sed -e "s/<i>/$count/g")"  
      directive_template="$(echo "${directive_template}" \
                       | sed -e "s/${directive_param}/$(escape ${par})/g")"                      
      ((count++))
   done
                                                           
   echo "${directive_template}"  
   
   return 0                                                       
}

#__build_rewrite_cond_directive "%{HTTP_USER_AGENT}"  "^ELB-HealthChecker/(.*)$"
#__build_rewrite_rule_directive "/elb.htm" "/var/www/html" "/elb.maxmin.it"
#__build_alias_directive 'elb.htm' '/var/www/html' 'elb.maxmin.it'
#__build_alias_directive 'webphp' '/var/www/html' 'elb.maxmin.it' 'index.php'
#__build_directory_element '/var/www/html' 'elb.maxmin.it'

#__add_virtualhost_element '127.0.0.1' '8090' 'admin.maxmin.it' '/var/www/html' 'admin.maxmin.it'  './virtual.conf'

#__add_alias_directive 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#__add_alias_directive 'webphp' '/var/www/html' 'elb.maxmin.it' './virtual.conf' 'index.php'

#__add_directory_element '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#__remove_directory_element '/var/www/html' 'elb.maxmin.it' './virtual.conf'

#__add_rewrite_engine_directive './virtual.conf'
#__add_rewrite_cond_directive "%{HTTP_USER_AGENT}"  "^ELB-HealthChecker/(.*)$" './virtual.conf'
#__add_rewrite_rule_directive "%{HTTP_USER_AGENT}"  "^ELB-HealthChecker/(.*)$" './virtual.conf'

#create_virtualhost_configuration_file '127.0.0.1' '8090' 'phpadmin.maxmin.it' '/var/www/html' 'phpadmin.maxmin.it' './virtual.conf'
#  add_alias_to_virtualhost 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'
#  add_alias_to_virtualhost 'webphp' '/var/www/html' 'webphp1.maxmin.it' './virtual.conf' 'index.php'
#  remove_alias_from_virtualhost 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'
#  remove_alias_from_virtualhost 'webphp' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'  

#  create_virtualhost_configuration_file '127.0.0.1' '8090' 'admin.maxmin.it' '/var/www/html' 'admin.maxmin.it'  './virtual.conf'
#  add_loadbalancer_rule_to_virtualhost 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#  remove_loadbalancer_rule_from_virtualhost 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
