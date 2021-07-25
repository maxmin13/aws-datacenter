#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
# https://jaletzki.de/posts/acme-dns-on-centos-7/
# In this post an acme-dns server will be set up and a client will 
# acquire a Let’s Encrypt certificate using the DNS-01 challenge.
# Acme-dns provides a simple API exclusively for TXT record updates 
# and should be used with ACME magic “_acme-challenge” - subdomain 
# CNAME records. This way, in the unfortunate exposure of API keys, 
# the effects are limited to the subdomain TXT record in question.
###################################################################

ADMIN_INST_USER_NM='SEDadmin_instance_user_nmSED'
GIT_ACME_DNS_URL='SEDacme_dns_urlSED'
ACME_DNS_CONFIG_DIR='SEDacme_dns_config_dirSED'
ACME_DNS_BINARY_DIR='SEDacme_dns_binary_dirSED'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo 'Installing Acme DNS server ...'

cd "${script_dir}" || exit

# Required programs.
amazon-linux-extras install epel -y
yum install -y git gcc go

echo 'Required programs installed.'

# Add a user for acme-dns service.
if id 'acme-dns' > /dev/null 2>&1
then
    echo 'acme-dns user alredy created.'
else
   adduser --system --home /var/lib/acme-dns acme-dns
   mkdir /var/lib/acme-dns
   chown acme-dns: /var/lib/acme-dns
fi

export CGO_CFLAGS="-g -O2 -Wno-return-local-addr" 
export GOPATH=/tmp/acme-dns

rm -rf acme-dns
git clone "${GIT_ACME_DNS_URL}"

echo 'Building acme-dns server ...'

cd acme-dns
go build

echo 'acme-dns built.'

cp -f acme-dns "${ACME_DNS_BINARY_DIR}"

echo 'acme-dns executable file moved in class-path.'

setcap 'cap_net_bind_service=+ep' "${ACME_DNS_BINARY_DIR}"/acme-dns

echo 'Allowed the acme-dns executable binding on port lower than 1000.'

cd "${script_dir}" || exit

cp -f acme-dns.service /etc/systemd/system
systemctl daemon-reload

echo 'acme-dns service file moved in the Systemd directory.'

mkdir -p "${ACME_DNS_CONFIG_DIR}"
cp -f config.cfg "${ACME_DNS_CONFIG_DIR}"    
        
echo 'acme-dns configuration file copied.'

# Install acme-dns as a service.
systemctl daemon-reload
systemctl enable acme-dns.service

echo 'Starting acme-dns service ...'

systemctl start acme-dns.service
systemctl status acme-dns.service

echo 'acme-dns service started.'

# Change ownership in the script directory otherwise it is not possible to delete 
# them from dev machine.
chown -R "${ADMIN_INST_USER_NM}":"${ADMIN_INST_USER_NM}" ./

amazon-linux-extras disable epel -y > /dev/null 2>&1

echo 'Acme DNS server installed.'

exit 0
