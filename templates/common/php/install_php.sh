#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

echo 'Installing PHP ...'
yum install -y php php-pear php-mysql
php -v
echo 'PHP installed'

cd /home/ec2-user || exit
cp -f php.ini /etc
chown root:root /etc/php.ini
chmod 400 /etc/php.ini      
echo 'PHP configuration file copied to /etc directory' 

#echo 'Installing PHP security patch ...'
#amazon-linux-extras install epel -y
#yum -y install php-devel
#yum -y install php-suhosin
#amazon-linux-extras disable epel -y
#echo 'PHP security patch installed'

exit 0


