#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Install database from Admin server 

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
database_log_file=/var/log/database_install.log

echo 'Installing database ...' >> "${database_log_file}" 2>&1

yum install -y mysql >> "${database_log_file}" 2>&1

cd "${script_dir}"

mysql --host=SEDdatabase_hostSED \
      --user=SEDdatabase_main_userSED \
      --password=SEDdatabase_main_user_passwordSED \
      --execute='SOURCE dbs.sql' >> "${database_log_file}" 2>&1
      
echo 'Database installed' >> "${database_log_file}" 2>&1

echo 'Creating users ...' >> "${database_log_file}" 2>&1

mysql --host=SEDdatabase_hostSED \
      --user=SEDdatabase_main_userSED \
      --password=SEDdatabase_main_user_passwordSED \
      --execute='SOURCE dbusers.sql' >> "${database_log_file}" 2>&1

echo 'Users created' >> "${database_log_file}" 2>&1

echo 'Verifing database ...' >> "${database_log_file}" 2>&1

mysql --host=SEDdatabase_hostSED \
      --user=SEDdatabase_main_userSED \
      --password=SEDdatabase_main_user_passwordSED \
      --database=SEDdatabase_nameSED \
      --execute='show tables;' >> "${database_log_file}" 2>&1
      
mysql --host=SEDdatabase_hostSED \
      --user=SEDdatabase_main_userSED \
      --password=SEDdatabase_main_user_passwordSED \
      --database=SEDdatabase_nameSED \
      --execute='select host, user from mysql.user;' >> "${database_log_file}" 2>&1      

echo 'Database tested' >> "${database_log_file}" 2>&1

echo 'Database installed.'

exit 0


