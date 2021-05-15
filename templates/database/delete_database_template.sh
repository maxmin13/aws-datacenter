#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Delete Database from Admin server

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
database_log_file=/var/log/database_delete.log

echo "Deleting Database ..." >> "${database_log_file}" 2>&1

cd "${script_dir}"

mysql --host=SEDdatabase_hostSED \
      --user=SEDdatabase_main_userSED \
      --password=SEDdatabase_main_user_passwordSED \
      --execute="SOURCE delete_dbs.sql" >> "${database_log_file}" 2>&1

echo "Database deleted" >> "${database_log_file}" 2>&1

echo "Deleting users ..." >> "${database_log_file}" 2>&1

mysql --host=SEDdatabase_hostSED \
      --user=SEDdatabase_main_userSED \
      --password=SEDdatabase_main_user_passwordSED \
      --execute="SOURCE delete_dbusers.sql" >> "${database_log_file}" 2>&1

echo "Users deleted" >> "${database_log_file}" 2>&1 

echo 'Database deleted.'

exit 0


