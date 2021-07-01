#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

dump_log_file='/var/log/dump_database.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Installing Mysql client ...' >> "${dump_log_file}" 2>&1

yum install -y mysql >> "${dump_log_file}" 2>&1

echo 'Mysql client installed.' >> "${dump_log_file}" 2>&1
echo 'Dumping the database:' >> "${dump_log_file}" 2>&1
echo '* host: SEDdatabase_hostSED' >> "${dump_log_file}" 2>&1
echo '* database name: SEDdatabase_nameSED' >> "${dump_log_file}" 2>&1
echo '* user: SEDdatabase_main_userSED' >> "${dump_log_file}" 2>&1

cd "${script_dir}" || exit 1

mysqldump --host=SEDdatabase_hostSED --user=SEDdatabase_main_userSED --password=SEDdatabase_main_user_passwordSED SEDdatabase_nameSED > SEDdump_dirSED/SEDdump_fileSED

echo 'Database dumped' >> "${dump_log_file}" 2>&1
echo 'Database dumped in SEDdump_dirSED directory.'
