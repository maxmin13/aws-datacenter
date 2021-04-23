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
#  create_virtual_host_configuration_file '127,0.0.1' '8090' 'admin.maxmin.it' './virtual.conf'
#  add_alias_to_virtual_host 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'
#  remove_alias_from_virtual_host 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'
# 
#  <VirtualHost 127.0.0.1:8090>
#     ServerName admin.maxmin.it
#     Alias /phpmyadmin /var/www/html/phpmyadmin.maxmin.it/public_html/phpmyadmin
#  </VirtualHost>
# 
#  <Directory /var/www/html/phpmyadmin.maxmin.it/public_html>
#     Require all granted
#  </Directory>
#
# Ex:
#
#  create_virtual_host_configuration_file '127,0.0.1' '8090' 'admin.maxmin.it' './virtual.conf'
#  add_loadbalancer_rule_to_virtual_host 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#  remove_loadbalancer_rule_from_virtual_host 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#
#  <VirtualHost 127.0.0.1:8090>
#     ServerName admin.maxmin.it
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

function create_virtual_host_configuration_file()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local address="${1}"
   local port="${2}"
   local hostname="${3}"
   local virtual_host_file="${4}"
   
   __add_virtual_host_element "${address}" "${port}" "${hostname}" "${virtual_host_file}"
 
   return 0
}

function add_alias_to_virtual_host()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias="${1}"
   local document_root="${2}"
   local alias_domain="${3}"
   local virtual_host_file="${4}"
   
   __add_alias_directive "${alias}" "${document_root}" "${alias_domain}" "${virtual_host_file}" 
   __add_directory_element "${document_root}" "${alias_domain}" "${virtual_host_file}" 
 
   return 0
}

function remove_alias_from_virtual_host()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias="${1}"
   local document_root="${2}"
   local alias_domain="${3}"
   local virtual_host_file="${4}"
   
   __remove_directive "Alias /${alias}" "${virtual_host_file}" 
   __remove_directory_element "${document_root}" "${alias_domain}" "${virtual_host_file}" 
   
   return 0
} 

function add_loadbalancer_rule_to_virtual_host()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias="${1}"
   local document_root="${2}"
   local alias_domain="${3}"
   local virtual_host_file="${4}"

   # For mod_rewrite, you need to escape the space and forward slash in the regular expression pattern:
   # the regex of: ^ELB-HealthChecker/1.0$ would be: ^ELB-HealthChecker\\\\/(.*)$ 
                              
   substitution="${document_root}/${alias_domain}/public_html/${alias}"
  
   __add_rewrite_engine_directive "${virtual_host_file}"
   __add_log_level_directive "${virtual_host_file}"
   __add_rewrite_cond_directive '%{HTTP_USER_AGENT}'  '^ELB-HealthChecker\\\\/(.*)$' "${virtual_host_file}"
   __add_rewrite_rule_directive "${alias}" "${substitution}" "${virtual_host_file}"
   __add_directory_element "${document_root}" "${alias_domain}" "${virtual_host_file}"                                 
 
   return 0
}

function remove_loadbalancer_rule_from_virtual_host()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias="${1}"
   local document_root="${2}"
   local alias_domain="${3}"
   local virtual_host_file="${4}"

   # RewriteCond directive
   __remove_directive '%{HTTP_USER_AGENT}' "${virtual_host_file}" 
   # RewriteRule directive
   __remove_directive "RewriteRule ${alias}" "${virtual_host_file}"
   # RewriteEngine directive
   __remove_directive 'RewriteEngine' "${virtual_host_file}"
   # LogLevel directive
   __remove_directive 'LogLevel' "${virtual_host_file}"
   __remove_directory_element "${document_root}" "${alias_domain}" "${virtual_host_file}"                            
 
   return 0
}

function __add_virtual_host_element()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local address="${1}"
   local port="${2}"
   local hostname="${3}"
   local virtual_host_file="${4}"
   local temp

   cat <<EOF > "${virtual_host_file}"
<VirtualHost SEDaddressSED:SEDportSED>
   ServerName SEDserver_hostnameSED
</VirtualHost>
EOF

   temp="$(sed -e "s/SEDaddressSED/${address}/g" \
               -e "s/SEDportSED/${port}/g" \
               -e "s/SEDserver_hostnameSED/${hostname}/g" \
                  "${virtual_host_file}")" 
                                                 
   echo "${temp}" > "${virtual_host_file}"
   
   return 0
}

function __add_directory_element()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local document_root="${1}"
   local alias_domain="${2}" 
   local virtual_host_file="${3}"   
   local directory_element 
   
   directory_element="$(__build_directory_element "${document_root}" "${alias_domain}")"
   
   # Add the element
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
   
   local document_root="${1}"
   local alias_domain="${2}"
   local virtual_host_file="${3}" 
   local directory_element temp

   sed -i "/<Directory $(escape "${document_root}"/"${alias_domain}"/public_html)/,/<\/Directory>/d" "${virtual_host_file}"

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
   local rewrite_cond_directive temp 
   
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
   
   local alias="${1}"
   local document_root="${2}"
   local alias_domain="${3}"
   local virtual_host_file="${4}"               
   local alias_directive
   
   alias_directive="$(__build_alias_directive "${alias}" "${document_root}" "${alias_domain}")"
     
   # Add the Alias directive before the </VirtualHost> element.
   sed -i "/^<\/VirtualHost>/i ${alias_directive}" "${virtual_host_file}"
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

   local document_root="${1}"
   local alias_domain="${2}" 
   local directory_element_template='<Directory SEDapache_doc_root_dirSED/SEDalias_domainSED/public_html>\n   Require all granted\n</Directory>\n'

   directory_element="$(printf '%b\n' "${directory_element_template}" \
                        | sed -e "s/SEDalias_domainSED/${alias_domain}/g" \
                              -e "s/SEDapache_doc_root_dirSED/$(escape "${document_root}")/g")"               

   echo "${directory_element}"
}

function __build_alias_directive()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error: missing mandatory arguments'
      exit 1
   fi
   
   local alias="${1}"
   local document_root="${2}"
   local alias_domain="${3}"
   local directive   
                                    
   directive="$(__build_directive 'false' 'Alias /SEDpar1SED SEDpar2SED/SEDpar3SED/public_html/SEDpar1SED' "${alias}" "${document_root}" "${alias_domain}")"  
   
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

# Builds a httpd directive, given a template in the form:
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
#__build_directory_element '/var/www/html' 'elb.maxmin.it'

#__add_virtual_host_element '127.0.0.1' '8090' 'admin.maxmin.it' './virtual.conf'

#__add_directory_element '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#__remove_directory_element '/var/www/html' 'elb.maxmin.it' './virtual.conf'

#__add_rewrite_engine_directive './virtual.conf'
#__add_rewrite_cond_directive "%{HTTP_USER_AGENT}"  "^ELB-HealthChecker/(.*)$" './virtual.conf'
#__add_rewrite_rule_directive "%{HTTP_USER_AGENT}"  "^ELB-HealthChecker/(.*)$" './virtual.conf'

#  create_virtual_host_configuration_file '127,0.0.1' '8090' 'admin.maxmin.it' './virtual.conf'
#  add_alias_to_virtual_host 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'
# remove_alias_from_virtual_host 'phpmyadmin' '/var/www/html' 'phpmyadmin.maxmin.it' './virtual.conf'

#  create_virtual_host_configuration_file '127,0.0.1' '8090' 'admin.maxmin.it' './virtual.conf'
#  add_loadbalancer_rule_to_virtual_host 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
#  remove_loadbalancer_rule_from_virtual_host 'elb.htm' '/var/www/html' 'elb.maxmin.it' './virtual.conf'
