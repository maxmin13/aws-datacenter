#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##
## PHP Thread safety note:
##
## Speaking only of Unix-based environments, you only have to think of PHP thread safety if you are going to use PHP with Apache web server, 
## in which case you are advised to go with the 'prefork' MPM of Apache, which doesn't use threads, and therefore, PHP thread-safety doesn't matter.
## Usually all GNU/Linux distributions will take that decision for you when you are installing Apache + PHP through their package system,  
## without even prompting you for a choice. 
## If you are going to use other webservers such as nginx or lighttpd, you won't have the option to embed PHP into them anyway. 
## You will be looking at using FastCGI or something equal which works in a different model where PHP is totally outside of the web server 
## with multiple PHP processes used for answering requests through e.g. FastCGI. For such cases, thread-safety also doesn't matter. 
##
## FastCGI is a binary 'protocol' for interfacing interactive programs with a web server. 
## It is a variation on the earlier Common Gateway Interface (CGI). 
## FastCGI is a method for executing dynamic program code from a web server. It is a very fast method which for the most part leaves 
## the server untouched and runs the application on a separate daemon. 
## To increase the speed, FastCGI provides multiple instances of this daemon, allowing requests to be processed without having to wait. 
## In practice, this is a promising gain in performance and, more importantly, an architecture that saves memory.
## 
## FPM (FastCGI Process Manager) is an alternative 'PHP FastCGI implementation' with some additional features (mostly) useful for heavy-loaded sites.
## Configuration file: php-fpm.conf
## systemctl enable php-fpm.service
## systemctl start php-fpm.service
##
## mod_fcgid is an Apache module that uses the FastCGI protocol to provide an interface between Apache and Common Gateway Interface (CGI) programs.
##
## Running PHP through mod_fcgid helps to reduce the amount of system resources used by forcing the web server to act as a proxy and only pass 
## files ending with the .php file extension to PHP-FPM.
##
## Files required to be uploaded:
## 1) cp 09-fcgid.conf 
## 2) cp 10-fcgid.conf 

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APACHE_INSTALL_DIR='SEDapache_install_dirSED'

echo 'Installing mod_fcgid and php-fpm ...'
yum install -y mod_fcgid php-fpm
echo 'mod_fcgid and php-fpm installed'

# Configure PHP-FPM to use UNIX sockets instead of TCP.
are_sockets_used="$(grep -E '^\s*listen\s*=\s*[a-zA-Z/]+' /etc/php-fpm.d/www.conf || true)"

# TODO
# main PHP pool configuration file
if [[ -z "${are_sockets_used}" ]]
then
   ## add:     listen = /var/run/php-fpm/www.sock
   ## comment: listen = 127.0.0.1:9000
   echo 'TODO: PHP-FPM configured to use UNIX sockets instead of TCP'
else 
   echo 'TODO: PHP-FPM already configured to use UNIX sockets instead of TCP'
fi

## FastCGI module’s configuration
cd "${script_dir}" || exit
cp 09-fcgid.conf "${APACHE_INSTALL_DIR}/conf.d"
cp 10-fcgid.conf "${APACHE_INSTALL_DIR}/conf.d"

# Set files and directories permissions
find "${APACHE_INSTALL_DIR}"/conf.d -type f -exec chown root:root {} +
find "${APACHE_INSTALL_DIR}"/conf.d -type f -exec chmod 400 {} +

# Check the configuration files syntax.
httpd -t

systemctl enable php-fpm
systemctl start php-fpm
systemctl restart httpd

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

echo 'FastCGI modules configured'

exit 0


