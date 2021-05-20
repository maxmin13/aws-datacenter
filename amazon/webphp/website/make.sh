#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###############################################
# Deploy the WebPhp website
#
# parameters <N> where this is the Nth web box 
# (1-5)
#
# GLOBAL: webphp_id, required
###############################################

APACHE_DOCROOT_DIR='/var/www/html'
APACHE_SITES_AVAILABLE_DIR='/etc/httpd/sites-available'
APACHE_SITES_ENABLED_DIR='/etc/httpd/sites-enabled'
WEBSITE_VIRTUALHOST_CONFIG_FILE='webphp.virtualhost.maxmin.it.conf' 
WEBSITE_DOCROOT_ID='webphp<ID>.maxmin.it'
WEBSITE_ARCHIVE='webphp.zip'

if [[ $# -lt 1 ]]
then
   echo 'Error: Missing mandatory arguments'
   exit 1
else
   webphp_id="${1}"
   export webphp_id="${1}"
fi

webphp_nm="${SERVER_WEBPHP_NM/<ID>/${webphp_id}}"
webphp_keypair_nm="${SERVER_WEBPHP_KEY_PAIR_NM/<ID>/${webphp_id}}"
webphp_sgp_nm="${SERVER_WEBPHP_SEC_GRP_NM/<ID>/${webphp_id}}"
webphp_dir=webphp"${webphp_id}"
website_request_domain="${SERVER_WEBPHP_HOSTNAME/<ID>/${webphp_id}}"
website_docroot_id="${WEBSITE_DOCROOT_ID/<ID>/${webphp_id}}"

echo '****************'
echo "WebPhp website ${webphp_id}" 
echo '****************'
echo

webphp_instance_id="$(get_instance_id "${webphp_nm}")"

if [[ -z "${webphp_instance_id}" ]]
then
   echo '* ERROR: webphp instance not found'
   exit 1
fi

webphp_sgp_id="$(get_security_group_id "${webphp_sgp_nm}")"

if [[ -z "${webphp_sgp_id}" ]]
then
   echo '* ERROR: webPhp security group not found'
   exit 1
else
   echo "* webPhp security group ID: '${webphp_sgp_id}'"
fi

eip="$(get_public_ip_address_associated_with_instance "${webphp_nm}")"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: webPhp public IP address not found'
   exit 1
else
   echo "* webPhp public IP address: '${eip}'"
fi

loadbalancer_sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -z "${loadbalancer_sgp_id}" ]]
then
   echo '* ERROR: load balancer security group not found'
   exit 1
else
   echo "* load balancer security group ID: '${loadbalancer_sgp_id}'"
fi

echo

# Clear old files
# shellcheck disable=SC2115
rm -rf "${TMP_DIR:?}"/"${webphp_dir}"
mkdir "${TMP_DIR}"/"${webphp_dir}"

## 
## SSH access to the webphp instance
## 

# Check if the WebPhp Security Group grants access from the development machine through SSH port
my_ip="$(curl -s "${AMAZON_CHECK_IP_URL}")"
access_granted="$(check_access_from_cidr_is_granted "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" '0.0.0.0/0')"
##### access_granted="$(check_access_from_cidr_is_granted "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32")"
 
if [[ -z "${access_granted}" ]]
then
   allow_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
   #####allow_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo "Granted SSH access to development machine"  
else
   echo 'SSH access already granted to development machine'    
fi

echo 'Waiting for SSH to start'
private_key="$(get_private_key_path "${webphp_keypair_nm}" "${WEBPHP_ACCESS_DIR}")"
wait_ssh_started "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}"

## ******* ##
## Website ##
## ******* ## 

## Prepare the archive with the website sources
cd "${TMP_DIR}"/"${webphp_dir}" || exit
cp -R "${WEBPHP_SRC_DIR}" './'

if [[ 'development' == "${ENV}" ]]
then
   cd "${TMP_DIR}"/"${webphp_dir}"/webphp/phpinclude || exit
   sed -i -e "s/SEDsend_email_fromSED/${SERVER_WEBPHP_EMAIL}/g" \
          -e "s/SEDminifed_jscssSED/0/g" \
              globalvariables.php 

elif [[ 'production' == "${ENV}" ]]
then 
   cd "${TMP_DIR}"/"${webphp_dir}"/webphp/phpinclude || exit
   sed -i -e "s/SEDsend_email_fromSED/${SERVER_WEBPHP_EMAIL}/g" \
          -e "s/SEDminifed_jscssSED/1/g" \
              globalvariables.php 
              
    # Minify javascript files.
    cd "${TMP_DIR}/${webphp_dir}"/webphp/jscss || exit

    # create a concatenation of all javascript files
    cat signup.js > general.js && rm -f signup.sh
    cat jquery.base64.min.js >> general.js && rm -f jquery.base64.min.js
      
    java -jar "${JAR_DIR}"/yuicompressor-2.4.8.jar general.js -o general.min.js
    echo 'Javascript files minified'
    
    # remove the unminified files
    rm -f general.js jquery.js signup.js      
fi 

## Prepare the archives.
echo 'Preparing the archives with the webphp site source files ...'

cd "${TMP_DIR}"/"${webphp_dir}"/webphp || exit
zip -r ../"${WEBSITE_ARCHIVE}" ./* > /dev/null 2>&1

echo "${WEBSITE_ARCHIVE} ready"
         
# Create the website virtualhost file.   
create_virtualhost_configuration_file '*' \
                  "${SERVER_WEBPHP_APACHE_WEBSITE_PORT}" \
                  "${website_request_domain}" \
                  "${APACHE_DOCROOT_DIR}" \
                  "${website_docroot_id}" \
                  "${TMP_DIR}"/"${webphp_dir}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}"     
                                     
add_alias_to_virtualhost 'webphp' \
                  "${APACHE_DOCROOT_DIR}" \
                  "${website_docroot_id}" \
                  "${TMP_DIR}"/"${webphp_dir}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}" \
                  'index.php'
                            
echo "${WEBSITE_VIRTUALHOST_CONFIG_FILE} ready" 

sed -e "s/SEDapache_docroot_dirSED/$(escape ${APACHE_DOCROOT_DIR})/g" \
    -e "s/SEDapache_sites_available_dirSED/$(escape ${APACHE_SITES_AVAILABLE_DIR})/g" \
    -e "s/SEDapache_sites_enabled_dirSED/$(escape ${APACHE_SITES_ENABLED_DIR})/g" \
    -e "s/SEDwebphp_virtual_host_configSED/${WEBSITE_VIRTUALHOST_CONFIG_FILE}/g" \
    -e "s/SEDwebsite_archiveSED/${WEBSITE_ARCHIVE}/g" \
    -e "s/SEDwebsite_docroot_idSED/${website_docroot_id}/g" \
       "${TEMPLATE_DIR}"/webphp/website/install_webphp_website_template.sh > "${TMP_DIR}"/"${webphp_dir}"/install_webphp_website.sh  
       
echo 'install_webphp_website.sh ready'

## 
## Remote commands that have to be executed as priviledged user are run with sudo.
## The ec2-user sudo command has been configured with password.
## 

echo 'Uploading scripts to the webphp server ...'

remote_dir=/home/ec2-user/script

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
                  "${private_key}" \
                  "${eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}"   

scp_upload_files "${private_key}" "${eip}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${DEFAUT_AWS_USER}" "${remote_dir}" \
                  "${TMP_DIR}"/"${webphp_dir}"/"${WEBSITE_ARCHIVE}" \
                  "${TMP_DIR}"/"${webphp_dir}"/"${WEBSITE_VIRTUALHOST_CONFIG_FILE}" \
                  "${TMP_DIR}"/"${webphp_dir}"/install_webphp_website.sh 

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/install_webphp_website.sh" \
                  "${private_key}" \
                  "${eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}" \
                  "${SERVER_WEBPHP_EC2_USER_PWD}"

echo "Installing the webphp website ${webphp_id} ..."  

set +e                
ssh_run_remote_command_as_root "${remote_dir}/install_webphp_website.sh" \
                  "${private_key}" \
                  "${eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}" \
                  "${SERVER_WEBPHP_EC2_USER_PWD}"                         
exit_code=$?	
set -e

echo "Webphp website ${webphp_id} installed" 

echo 

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then 
   # Clear remote home directory    
   ssh_run_remote_command "rm -rf ${remote_dir:?}" \
                  "${private_key}" \
                  "${eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}"  
                   
   echo 'Rebooting instance ...'  
   set +e      
   ssh_run_remote_command_as_root 'reboot' \
                  "${private_key}" \
                  "${eip}" \
                  "${SHARED_BASE_INSTANCE_SSH_PORT}" \
                  "${DEFAUT_AWS_USER}" \
                  "${SERVER_WEBPHP_EC2_USER_PWD}" > /dev/null
   set -e   
else
   echo 'ERROR: running install_webphp_website.sh'
   exit 1
fi

##
## Grants to load balancer to access the webphp instance
## 

loadbalancer_sgp_id="$(get_security_group_id "${LBAL_SEC_GRP_NM}")"

if [[ -n "${loadbalancer_sgp_id}" ]]
then
   # Allow Load Balancer access to the instance.
   allow_access_from_security_group "${webphp_sgp_id}" "${SERVER_WEBPHP_APACHE_WEBSITE_PORT}" "${loadbalancer_sgp_id}"
   echo 'Granted the load balancer access to the webphp instance'
fi
                                   
## 
## SSH access to the instance
## 

if [[ -n "${webphp_sgp_id}" ]]
then
   revoke_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "0.0.0.0/0"
   #####revoke_access_from_cidr "${webphp_sgp_id}" "${SHARED_BASE_INSTANCE_SSH_PORT}" "${my_ip}/32"
   echo 'Revoked SSH access to the webphp instance'
fi

## 
## Clearing local files
## 

rm -rf "${TMP_DIR:?}"/"${webphp_dir}"

echo "Website ${webphp_id} up and running at: '${eip}'" 
echo

