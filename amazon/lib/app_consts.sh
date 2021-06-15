#!/usr/bin/bash

# shellcheck disable=SC2034

ENV='development'
#ENV='production'

## Amazon EBS-backed image:
## By default, the root volume is deleted when the instance terminates.
## Data on any other EBS volumes persists after instance termination by default.
AWS_BASE_AMI_ID='ami-0bb3fad3c0286ebd5'
AWS_CHECK_IP_URL='http://checkip.amazonaws.com'

## ********** ##
## App domain ##
## ********** ##

MAXMIN_TLD='maxmin.it'

## *********** ##
## Data Center ##
## *********** ##

DTC_NM='maxmin-datacenter'
DTC_CDIR='10.0.0.0/16'
DTC_DEPLOY_REGION='eu-west-1'
DTC_DEPLOY_ZONE_1='eu-west-1a'
DTC_DEPLOY_ZONE_2='eu-west-1b'
DTC_SUBNET_MAIN_NM='maxmin-main-sbn'
DTC_SUBNET_MAIN_CIDR='10.0.0.0/24'
DTC_SUBNET_BACKUP_NM='maxmin-backup-sbn'
DTC_SUBNET_BACKUP_CIDR='10.0.10.0/24'
DTC_INTERNET_GATEWAY_NM='maxmin-gate'
DTC_ROUTE_TABLE_NM='maxmin-route-tb'

## ******************* ##
## Relational Database ##
## ******************* ##

DB_MMDATA_INSTANCE_NM='mmdatainstance'
DB_MMDATA_PORT='3306'
DB_MMDATA_NM='mmdata'
DB_MMDATA_LOG_SLOW_QUERIES_PARAM_GRP_NM='logslowqueries' ## can't have capitals
DB_MMDATA_LOG_SLOW_QUERIES_PARAM_GRP_DESC='Log slow queries database parameter group'
DB_MMDATA_SUB_GRP_NM='maxmin-rds-subgp'
DB_MMDATA_SUB_GRP_DESC='Database Subnet Group that spans multiple subnets'
DB_MMDATA_SEC_GRP_NM='maxmin-rds-sgp'
# The db main user is set when the db is created, see: rds.sh
DB_MMDATA_MAIN_USER_NM='maxmin'
DB_MMDATA_ADMIN_USER_NM='adminrw'
DB_MMDATA_WEBPHP_USER_NM='webphprw'
DB_MMDATA_JAVAMAIL_USER_NM='javamail'

## ************ ##
## Shared image ##
## ************ ##

SHAR_INSTANCE_NM='maxmin-shared-instance'
SHAR_INSTANCE_HOSTNAME='shared.maxmin.it'
SHAR_INSTANCE_USER_NM='shared-user'
SHAR_INSTANCE_PRIVATE_IP='10.0.0.8'
SHAR_INSTANCE_SSH_PORT='38142'
SHAR_INSTANCE_KEY_PAIR_NM='maxmin-shared-kp'
SHAR_INSTANCE_SEC_GRP_NM='maxmin-shared-instance-sgp'
SHAR_IMAGE_NM='maxmin-shared-ami'
SHAR_IMAGE_DESC='Linux secured Image'

## ************* ##
## Load Balancer ##
## ************* ##

LBAL_NM='elbmaxmin'
LBAL_PORT='443'
LBAL_EMAIL_ADD='minardi.massimiliano@libero.it'
LBAL_SEC_GRP_NM='maxmin-elb-sgp'
LBAL_DNS_SUB_DOMAIN='www'

## ********* ##
## Admin box ##
## ********* ##

SRV_ADMIN_NM='maxmin-admin-instance'
SRV_ADMIN_PRIVATE_IP='10.0.0.10'
SRV_ADMIN_HOSTNAME='admin.maxmin.it'
SRV_ADMIN_USER_NM='admin-user'
# In dev, ip-base virtual hosting, in prod name-base virtual hosting with only one ip and port for
# website, phpmyadmin and loganalyzer.
SRV_ADMIN_APACHE_WEBSITE_HTTP_PORT='80'
SRV_ADMIN_APACHE_WEBSITE_HTTPS_PORT='443'
SRV_ADMIN_APACHE_DEFAULT_HTTP_PORT='8070'
SRV_ADMIN_APACHE_PHPMYADMIN_HTTP_PORT='8080'
SRV_ADMIN_APACHE_PHPMYADMIN_HTTPS_PORT='9443'
SRV_ADMIN_APACHE_LOGANALYZER_HTTP_PORT='8081'
SRV_ADMIN_APACHE_LOGANALYZER_HTTPS_PORT='9444'
SRV_ADMIN_APACHE_MONIT_HTTP_PORT='8082'
SRV_ADMIN_MMONIT_HTTP_PORT='8083'
SRV_ADMIN_MMONIT_HTTPS_PORT='9445'
SRV_ADMIN_MMONIT_COLLECTOR_PORT='8084'
SRV_ADMIN_RSYSLOG_PORT='514'
SRV_ADMIN_EMAIL='minardi.massimiliano@libero.it'
SRV_ADMIN_KEY_PAIR_NM='maxmin-admin-kp'
SRV_ADMIN_SEC_GRP_NM='maxmin-admin-instance-sgp'
SRV_ADMIN_DNS_SUB_DOMAIN='admin'

## ********** ##
## WebPhp box ##
## ********** ##

SRV_WEBPHP_NM='maxmin-webphp<ID>-instance'
SRV_WEBPHP_PRIVATE_IP='10.0.0.2<ID>'
SRV_WEBPHP_HOSTNAME='webphp<ID>.maxmin.it'
SRV_WEBPHP_USER_NM='webphp-user'
# In dev, ip-base virtual hosting, in prod name-base virtual hosting with only one ip and port for
# website, loadbalancer (instance healt heart-bit) and monit (httpd healt heart-bit).
SRV_WEBPHP_APACHE_DEFAULT_HTTP_PORT='8050'
SRV_WEBPHP_APACHE_MONIT_HTTP_PORT='8060'
SRV_WEBPHP_APACHE_WEBSITE_HTTP_PORT='8070'
SRV_WEBPHP_APACHE_LBAL_HEALTCHECK_HTTP_PORT='8080'
SRV_WEBPHP_RSYSLOG_PORT='514'
SRV_WEBPHP_SEC_GRP_NM='maxmin-webphp<ID>-instance-sgp'
SRV_WEBPHP_KEY_PAIR_NM='maxmin-webphp<ID>-kp'
SRV_WEBPHP_EMAIL='minardi.massimiliano@libero.it'


