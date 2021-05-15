#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Installing PHP ...'
yum install -y php php-pear php-mysql
php -v
echo 'PHP installed'

cd "${script_dir}" || exit
cp -f php.ini /etc
chown root:root /etc/php.ini
chmod 400 /etc/php.ini      
echo 'PHP configuration file copied to /etc directory' 

exit 0


