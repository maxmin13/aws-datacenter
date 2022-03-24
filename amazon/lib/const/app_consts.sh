#!/usr/bin/bash

# shellcheck disable=SC2034

# Development uses a self-signed certificate.
ENV='development'
# Production uses a Let's Encrypt certificate.
#ENV='production'

## Amazon EBS-backed image:
## By default, the root volume is deleted when the instance terminates.
## Data on any other EBS volumes persists after instance termination by default.
AWS_BASE_IMG_ID='ami-058b1b7fe545997ae' 
AWS_CHECK_IP_URL='http://checkip.amazonaws.com'

## ********** ##
## App domain ##
## ********** ##

MAXMIN_TLD='maxmin.it.'

## *********** ##
## Data center ##
## *********** ##

DTC_NM='maxmin-dtc'
DTC_CDIR='10.0.0.0/16' # the first four adresses are reserved by AWS.
DTC_INTERNET_GATEWAY_NM='internet-gate'
DTC_REGION='eu-west-1'
DTC_AZ_1='eu-west-1a'
DTC_SUBNET_MAIN_NM='main-sbn'
DTC_SUBNET_MAIN_CIDR='10.0.10.0/24'
DTC_SUBNET_MAIN_INTERNAL_GATEWAY_IP='10.0.10.1'
DTC_AZ_2='eu-west-1b'
DTC_SUBNET_BACKUP_NM='backup-sbn'
DTC_SUBNET_BACKUP_CIDR='10.0.20.0/24'
DTC_SUBNET_BACKUP_INTERNAL_GATEWAY_IP='10.0.20.1'
DTC_SUBNET_BACKUP_RESERVED_IPS='10.0.20.1-10.0.20.29'
DTC_ROUTE_TABLE_NM='route-tab'

## ************ ##
## Permissions  ##
## ************ ##

AWS_ROUTE53_ROLE_NM='Route53role'
AWS_ROUTE53_POLICY_NM='Route53policy'
AWS_BOSH_DIRECTOR_ROLE_NM='BoshDirectorRole'
AWS_BOSH_DIRECTOR_POLICY_NM='AdministratorAccess'

## ******** ##
## Database ##
## ******** ##

DB_INST_NM='mmdatainstance'
DB_INST_SUBNET_GRP_NM='db-sbng'
DB_INST_SUBNET_GRP_DESC='Database subnet group that spans multiple subnets'
DB_INST_SEC_GRP_NM='db-sgp'
DB_INST_PORT='3306'
DB_NM='mmdata'
DB_MAIN_USER_NM='maxmin'
DB_ADMIN_USER_NM='adminrw'
DB_WEBPHP_USER_NM='webphprw'
DB_JAVAMAIL_USER_NM='javamail'
DB_LOG_SLOW_QUERIES_PARAM_GRP_NM='logslowqueries' ## can't have capitals
DB_LOG_SLOW_QUERIES_PARAM_GRP_DESC='Log slow queries database parameter group'

## ************ ##
## Shared image ##
## ************ ##

SHARED_INST_NM='shared-box'
SHARED_INST_HOSTNAME='shared.maxmin.it'
SHARED_INST_USER_NM='shared-user'
SHARED_INST_PRIVATE_IP='10.0.10.5'
SHARED_INST_SSH_PORT='38142'
SHARED_INST_KEY_PAIR_NM='shared-key'
SHARED_INST_SEC_GRP_NM='shared-box-sgp'
SHARED_IMG_NM='shared-img'
SHARED_IMG_DESC='Linux secured Image'

## ************* ##
## Load balancer ##
## ************* ##

LBAL_INST_NM='lbalmaxmin'
LBAL_INST_HTTPS_PORT='443'
LBAL_INST_HTTP_PORT='80'
LBAL_INST_SEC_GRP_NM='lbal-sgp'
LBAL_INST_DNS_DOMAIN_NM='www'."${MAXMIN_TLD}"
LBAL_EMAIL_ADD='minardi.massimiliano@libero.it'

## ********* ##
## Admin box ##
## ********* ##

ADMIN_INST_NM='admin-box'
ADMIN_INST_PRIVATE_IP='10.0.10.6'
ADMIN_INST_HOSTNAME='admin.maxmin.it'
ADMIN_INST_USER_NM='admin-user'
ADMIN_INST_EMAIL='minardi.massimiliano@libero.it'
ADMIN_INST_KEY_PAIR_NM='admin-key'
ADMIN_INST_SEC_GRP_NM='admin-box-sgp'
ADMIN_INST_DNS_DOMAIN_NM='admin'."${MAXMIN_TLD}"
ADMIN_INST_PROFILE_NM="AdmInstanceProfile"
ADMIN_APACHE_CERTBOT_HTTP_PORT='80'
ADMIN_APACHE_WEBSITE_HTTP_PORT='8060'
ADMIN_APACHE_WEBSITE_HTTPS_PORT='443'
ADMIN_APACHE_DEFAULT_HTTP_PORT='8070'
ADMIN_APACHE_PHPMYADMIN_HTTP_PORT='8080'
ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT='9443'
ADMIN_APACHE_LOGANALYZER_HTTP_PORT='8081'
ADMIN_APACHE_LOGANALYZER_HTTPS_PORT='9444'
ADMIN_APACHE_MONIT_HTTP_PORT='8082'
ADMIN_ACME_DNS_HTTP_PORT='8082'
ADMIN_ACME_DNS_HTTPS_PORT='9446'
ADMIN_ACME_DNS_PORT='53'
ADMIN_MMONIT_HTTP_PORT='8083'
ADMIN_MMONIT_HTTPS_PORT='9445'
ADMIN_MMONIT_COLLECTOR_PORT='8084'
ADMIN_RSYSLOG_PORT='514'

## ********** ##
## WebPhp box ##
## ********** ##

WEBPHP_INST_NM='webphp<ID>-box'
WEBPHP_INST_PRIVATE_IP='10.0.10.1<ID>'
WEBPHP_INST_HOSTNAME='webphp<ID>.maxmin.it'
WEBPHP_INST_USER_NM='webphp-user'
WEBPHP_INST_SEC_GRP_NM='webphp<ID>-box-sgp'
WEBPHP_INST_KEY_PAIR_NM='webphp<ID>-key'
WEBPHP_INST_EMAIL='minardi.massimiliano@libero.it'
WEBPHP_APACHE_DEFAULT_HTTP_PORT='8050'
WEBPHP_APACHE_MONIT_HTTP_PORT='8060'
WEBPHP_APACHE_WEBSITE_HTTP_PORT='8070'
WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT='8080'
WEBPHP_RSYSLOG_PORT='514'

