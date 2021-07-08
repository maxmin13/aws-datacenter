#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
# 
###################################################################

GIT_ACME_DNS_URL='SEDacme_dns_urlSED'
ACME_DNS_SERVER_IP_ADD='SEDacme_dns_server_ip_addSED'
ACME_DNS_CONFIG_FILE='SEDacme_dns_config_fileSED'
acme_dns_install_log_file='/var/log/acme_dns_install_log_file.log'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Installing Acme DNS server ...'

cd "${script_dir}" || exit

# Required programs.
yum install -y git gcc go > "${acme_dns_install_log_file}"
yum remove -y certbot > "${acme_dns_install_log_file}"
yum install -y certbot python2-certbot-apache > "${acme_dns_install_log_file}"

echo 'Certbot SSL agent installed.'

export CGO_CFLAGS="-g -O2 -Wno-return-local-addr" 
export GOPATH=/tmp/acme-dns
git clone "${GIT_ACME_DNS_URL}"
cd acme-dns
go build
mkdir /etc/acme-dns
#### cp config.cfg /etc/acme-dns/
mv acme-dns /usr/local/bin

# Add a user for the acme-dns service.
adduser --system --home /var/lib/acme-dns acme-dns
mkdir /var/lib/acme-dns
chown acme-dns: /var/lib/acme-dns

# Install acme-dns as a service.
mv acme-dns.service /etc/systemd/system
systemctl daemon-reload
systemctl enable acme-dns.service
systemctl start acme-dns.service
systemctl status acme-dns.service

echo 'Acme DNS server installed.'

exit 0
