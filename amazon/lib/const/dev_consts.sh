#!/usr/bin/bash

# shellcheck disable=SC2034

## ************* ##
## Load balancer ##
## ************* ##

# Certificate of the load balancer in front of webphp websites.
DEV_LBAL_CRT_COUNTRY_NM='IE'
DEV_LBAL_CRT_PROVINCE_NM='Dublin'
DEV_LBAL_CRT_CITY_NM='Dublin'
DEV_LBAL_CRT_ORGANIZATION_NM='WWW'
DEV_LBAL_CRT_UNIT_NM='lbal web' 

## ********* ##
## Admin box ##
## ********* ##

# Certificate used by apache.
DEV_ADMIN_CRT_COUNTRY_NM='IE'
DEV_ADMIN_CRT_PROVINCE_NM='Dublin'
DEV_ADMIN_CRT_CITY_NM='Dublin'
DEV_ADMIN_CRT_ORGANIZATION_NM='WWW'
DEV_ADMIN_CRT_UNIT_NM='admin web'

## ************** ##
## Cloud Foundry  ##
## ************** ##

# Load balancer certificate.
DEV_CF_CRT_COUNTRY_NM='IE'
DEV_CF_CRT_PROVINCE_NM='Dublin'
DEV_CF_CRT_CITY_NM='Dublin'
DEV_CF_CRT_ORGANIZATION_NM='WWW'
DEV_CF_CRT_UNIT_NM='CF web'




