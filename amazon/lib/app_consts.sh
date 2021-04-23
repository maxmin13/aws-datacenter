#!/usr/bin/bash

# shellcheck disable=SC2034

ENV='development'
# ENV='production'

AMAZON_CHECK_IP_URL='http://checkip.amazonaws.com'
DEFAUT_AWS_USER='ec2-user'

## *********** ##
## Data Center ##
## *********** ##

DEPLOY_REGION='eu-west-1'
DEPLOY_ZONE_1='eu-west-1a'
DEPLOY_ZONE_2='eu-west-1b'
VPC_NM='maxmin-vpc'
VPC_CDIR='10.0.0.0/16'
SUBNET_MAIN_NM='maxmin-main-sbn'
SUBNET_MAIN_CIDR='10.0.0.0/24'
SUBNET_BACKUP_NM='maxmin-backup-sbn'
SUBNET_BACKUP_CIDR='10.0.10.0/24'
INTERNET_GATEWAY_NM='maxmin-gate'
ROUTE_TABLE_NM='maxmin-route-tb'

## ******************* ##
## Relational Database ##
## ******************* ##

DB_MMDATA_INSTANCE_NM='mmdatainstance'
DB_MMDATA_NM='mmdata'
# the instance type to use (different from EC2 instance types)
# Represents compute and memory capacity class 
DB_MMDATA_INSTANCE_TYPE='db.t3.micro'
DB_MMDATA_VOLUME_SIZE='10' # in GB
# 1=use multi-az, 0=don't
DB_MMDATA_USE_MULTI_AZ='0'
DB_MMDATA_SUB_GRP_NM='maxmin-rds-subgp'
DB_MMDATA_SUB_GRP_DESC='Database Subnet Group that spans multiple subnets'
DB_MMDATA_SEC_GRP_NM='maxmin-rds-sgp'
DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_NM='slowqueries-mysql80'
DB_MMDATA_SLOW_QUERIES_LOG_PARAM_GRP_DESC='The database logs slow queries'
#DB_MMDATA_FAMILY='mysql8.0'
DB_MMDATA_FAMILY='mysql5.7'
#MYSQL_VERSION='8.0'
MYSQL_VERSION='5.7'
DB_MMDATA_ENGINE='MYSQL'
DB_MMDATA_PORT='3306'
# Disable automated database backups
DB_MMDATA_BACKUP_RET_PERIOD='0'
# The db main user is set when the db is created, see: rds.sh
DB_MMDATA_MAIN_USER_NM='maxmin'
DB_MMDATA_ADMIN_USER_NM='adminrw'
DB_MMDATA_WEBPHP_USER_NM='webphprw<ID>'
DB_MMDATA_JAVAMAIL_USER_NM='javamail'

## ***************** ##
## Shared Base image ##
## ***************** ##

## Amazon Linux 2 image
BASE_AMI_ID='ami-0bb3fad3c0286ebd5'
SHARED_BASE_INSTANCE_NM='maxmin-base-instance'
SHARED_BASE_INSTANCE_PRIVATE_IP='10.0.0.9'
SHARED_BASE_INSTANCE_SSH_PORT='38142'
SHARED_BASE_INSTANCE_ROOT_DEV_NM='/dev/xvda'
SHARED_BASE_INSTANCE_KEY_PAIR_NM='maxmin-base-kp'
SHARED_BASE_INSTANCE_SEC_GRP_NM='maxmin-base-instance-sgp'
SHARED_BASE_INSTANCE_TYPE='t2.micro'
SHARED_BASE_INSTANCE_EBS_VOL_SIZE='10' ## in GB, subsequent servers can be larger, but not smaller
SHARED_BASE_AMI_NM='maxmin-shared-ami'
SHARED_BASE_AMI_DESC='Maxmin Linux secured Image'

## ************* ##
## Load Balancer ##
## ************* ##

LBAL_NM='elbmaxmin'
LBAL_PORT='443'
LBAL_INSTANCE_PORT='8090'
LBAL_CRT_NM='maxmin-dev-elb-cert'
LBAL_CRT_FILE='maxmin-dev-elb-cert.pem'
LBAL_KEY_FILE='maxmin-dev-elb-key.pem'
LBAL_CHAIN_FILE='maxmin-dev-elb-chain.pem'
LBAL_CRT_COUNTRY_NM='IE'
LBAL_CRT_PROVINCE_NM='Dublin'
LBAL_CRT_CITY_NM='Dublin'
LBAL_CRT_COMPANY_NM='maxmin13'
LBAL_CRT_ORGANIZATION_NM='WWW'
LBAL_CRT_UNIT_NM='UN'
LBAL_CRT_COMMON_NM='www.maxmin.it'
LBAL_EMAIL_ADD='minardi.massimiliano@libero.it'
LBAL_SEC_GRP_NM='maxmin-elb-sgp'

## ********* ##
## Admin box ##
## ********* ##

SERVER_ADMIN_NM='maxmin-admin-instance'
SERVER_ADMIN_PRIVATE_IP='10.0.0.10'
SERVER_ADMIN_APACHE_HTTPS_PORT='443'
SERVER_ADMIN_APACHE_HTTP_PORT='8090'
SERVER_ADMIN_MMONIT_HTTPS_PORT='8443'
SERVER_ADMIN_MMONIT_HTTP_PORT='8080'
SERVER_ADMIN_MONIT_HTTP_PORT='2812'
SERVER_ADMIN_RSYSLOG_PORT='514'
SERVER_ADMIN_EMAIL='minardi.massimiliano@libero.it'
SERVER_ADMIN_ROOT_DEV_NM='/dev/xvda'
SERVER_ADMIN_KEY_PAIR_NM='maxmin-admin-kp'
SERVER_ADMIN_SEC_GRP_NM='maxmin-admin-instance-sgp'
SERVER_ADMIN_TYPE='t2.micro'
SERVER_ADMIN_EBS_VOL_SIZE='10' ## in GB, subsequent servers can be larger, but not smaller
SERVER_ADMIN_CRT_COUNTRY_NM='IE'
SERVER_ADMIN_CRT_PROVINCE_NM='Dublin'
SERVER_ADMIN_CRT_CITY_NM='Dublin'
SERVER_ADMIN_CRT_COMPANY_NM='maxmin13'
SERVER_ADMIN_CRT_ORGANIZATION_NM='WWW'
SERVER_ADMIN_CRT_UNIT_NM='UN'
SERVER_ADMIN_HOSTNAME='admin.maxmin.it'
SERVER_ADMIN_PHPMYADMIN_DOMAIN_NM='phpmyadmin.maxmin.it'
SERVER_ADMIN_LOGANALYZER_DOMAIN_NM='loganalyzer.maxmin.it'
SERVER_ADMIN_MONIT_HEARTBEAT_DOMAIN_NM='monit.maxmin.it'

## ********** ##
## WebPhp box ##
## ********** ##

SERVER_WEBPHP_NM='maxmin-webphp<ID>-instance'
SERVER_WEBPHP_APACHE_HTTP_PORT='8090'
SERVER_WEBPHP_RSYSLOG_PORT='514'
SERVER_WEBPHP_SEC_GRP_NM='maxmin-webphp<ID>-instance-sgp'
SERVER_WEBPHP_KEY_PAIR_NM='maxmin-webphp<ID>-kp'
SERVER_WEBPHP_TYPE='t2.micro'
SERVER_WEBPHP_ROOT_DEV_NM='/dev/xvda'
SERVER_WEBPHP_EBS_VOL_SIZE='10'
SERVER_WEBPHP_PRIVATE_IP='10.0.0.2<ID>'
SERVER_WEBPHP_EMAIL='minardi.massimiliano@libero.it'
SERVER_WEBPHP_HOSTNAME='webphp<ID>.maxmin.it'
SERVER_WEBPHP_MONIT_HEARTBEAT_DOMAIN_NM='monit.maxmin.it'
SERVER_WEBPHP_LOADBALANCER_HEARTBEAT_DOMAIN_NM='elb.maxmin.it'

