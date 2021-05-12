#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

## Install Apache Web Server SSL module and generate a primary-key and a certificate,
## Listen on 80 port, no SSL.

ENV='SEDenvironmentSED'
APACHE_INSTALL_DIR='SEDapache_install_dirSED'
APACHE_USR='SEDapache_usrSED'

yum install -y mod_ssl

mkdir -p "${APACHE_INSTALL_DIR}"/ssl

cd /home/ec2-user || exit
cp ssl.conf "${APACHE_INSTALL_DIR}"/conf.d
cp 00-ssl.conf "${APACHE_INSTALL_DIR}"/conf.modules.d

cd /home/ec2-user || exit

#if [[ 'development' == "${ENV}" ]]
if 'true'
then
   chmod +x gen-rsa.sh \
            remove-passphase.sh \
            gen-selfsign-cert.sh

   ./gen-rsa.sh 
   ./remove-passphase.sh 
   echo 'No-password private key generated'

   rm server.key && mv server.key.org server.key
   ./gen-selfsign-cert.sh 
   echo 'Self-signed certificate created'

   cp server.crt "${APACHE_INSTALL_DIR}"/ssl/server.crt
   cp server.key "${APACHE_INSTALL_DIR}"/ssl/server.key

#elif [[ 'production' == "${ENV}" ]]
#then
else
   # TODO
   # TODO Create a script to automate to get a production certificate from a CA
   # TODO put key, certificate and chain in ssl folder
   # TODO  
   
   echo 'Error: a production certificate is not available, use a developement self-signed one'
   exit 1
fi

# Set files and directories permissions
find "${APACHE_INSTALL_DIR}"/ssl -type d -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/ssl -type d -exec chmod 500 {} +
find "${APACHE_INSTALL_DIR}"/ssl -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/ssl -type f -exec chmod 400 {} +
find "${APACHE_INSTALL_DIR}"/conf.d -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.d -type f -exec chmod 400 {} +
find "${APACHE_INSTALL_DIR}"/conf.modules.d -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.modules.d -type f -exec chmod 400 {} +

# Check the syntax of configuration files.
httpd -t
systemctl restart httpd
echo 'Apache SSL module installed'

echo '-------------------------------------------------'
echo 'Directory modules:'
ls -lh "${APACHE_INSTALL_DIR}"/modules
echo '-------------------------------------------------'
echo 'Modules compiled statically into the server:'
/usr/sbin/httpd -l
echo '-------------------------------------------------'
echo 'Modules compiled dynamically enabled with Apache'
/usr/sbin/httpd -M
echo '-------------------------------------------------'
echo 'Server version:'
/usr/sbin/httpd -V
echo '-------------------------------------------------'

exit 0


