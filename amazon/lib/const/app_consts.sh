#!/usr/bin/bash

# shellcheck disable=SC2034

#ENV='development'
ENV='production'

## Amazon EBS-backed image:
## By default, the root volume is deleted when the instance terminates.
## Data on any other EBS volumes persists after instance termination by default.
AWS_BASE_IMG_ID='ami-058b1b7fe545997ae' 
AWS_CHECK_IP_URL='http://checkip.amazonaws.com'
ACME_DNS_GIT_REPOSITORY_URL='https://github.com/joohoi/acme-dns'
AWS_CLI_REPOSITORY_URL='https://awscli.amazonaws.com'

## ********** ##
## App domain ##
## ********** ##

MAXMIN_TLD='maxmin.it.'

## *********** ##
## Data center ##
## *********** ##

DTC_NM='maxmin-dtc'
DTC_CDIR='10.0.0.0/16'
DTC_DEPLOY_REGION='eu-west-1'
DTC_DEPLOY_ZONE_1='eu-west-1a'
DTC_DEPLOY_ZONE_2='eu-west-1b'
DTC_SUBNET_MAIN_NM='main-sbn'
DTC_SUBNET_MAIN_CIDR='10.0.0.0/24'
DTC_SUBNET_BACKUP_NM='backup-sbn'
DTC_SUBNET_BACKUP_CIDR='10.0.10.0/24'
DTC_INTERNET_GATEWAY_NM='internet-gate'
DTC_ROUTE_TABLE_NM='route-tab'

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

SHARED_INST_NM='shared-box1'
SHARED_INST_HOSTNAME='shared.maxmin.it'
SHARED_INST_USER_NM='shared-user'
SHARED_INST_PRIVATE_IP='10.0.0.8'
SHARED_INST_SSH_PORT='38142'
SHARED_INST_KEY_PAIR_NM='shared-keys'
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
LBAL_INST_DNS_SUB_DOMAIN='www'
LBAL_EMAIL_ADD='minardi.massimiliano@libero.it'

## ********* ##
## Admin box ##
## ********* ##

ADMIN_INST_NM='admin-box1'
ADMIN_INST_PRIVATE_IP='10.0.0.10'
ADMIN_INST_HOSTNAME='admin.maxmin.it'
ADMIN_INST_USER_NM='admin-user'
ADMIN_INST_EMAIL='minardi.massimiliano@libero.it'
ADMIN_INST_KEY_PAIR_NM='admin-keys'
ADMIN_INST_SEC_GRP_NM='admin-box-sgp'
ADMIN_INST_DNS_SUB_DOMAIN='admin'
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
ADMIN_ACME_DNS_HTTPS_PORT='9445'
ADMIN_ACME_DNS_PORT='53'
ADMIN_MMONIT_HTTP_PORT='8083'
ADMIN_MMONIT_HTTPS_PORT='9445'
ADMIN_MMONIT_COLLECTOR_PORT='8084'
ADMIN_RSYSLOG_PORT='514'

## ********** ##
## WebPhp box ##
## ********** ##

WEBPHP_INST_NM='webphp<ID>-box1'
WEBPHP_INST_PRIVATE_IP='10.0.0.2<ID>'
WEBPHP_INST_HOSTNAME='webphp<ID>.maxmin.it'
WEBPHP_INST_USER_NM='webphp-user'
WEBPHP_INST_SEC_GRP_NM='webphp<ID>-box-sgp'
WEBPHP_INST_KEY_PAIR_NM='webphp<ID>-keys'
WEBPHP_INST_EMAIL='minardi.massimiliano@libero.it'
WEBPHP_APACHE_DEFAULT_HTTP_PORT='8050'
WEBPHP_APACHE_MONIT_HTTP_PORT='8060'
WEBPHP_APACHE_WEBSITE_HTTP_PORT='8070'
WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT='8080'
WEBPHP_RSYSLOG_PORT='514'



