#!/usr/bin/bash 
 
# shellcheck disable=SC2034 

TMP_DIR="${PROJECT_DIR}"/temp
TEMPLATE_DIR="${PROJECT_DIR}"/templates
JAR_DIR="${PROJECT_DIR}"/jars
LOG_DIR="${PROJECT_DIR}"/logs

SHARED_BASE_INSTANCE_CREDENTIALS_DIR="${PROJECT_DIR}"/credentials/base

LBAL_CREDENTIALS_DIR="${PROJECT_DIR}"/credentials/elb/dev
# LBAL_CREDENTIALS_DIR="${PROJECT_DIR}"/credentials/elb/prod

ADMIN_CREDENTIALS_DIR="${PROJECT_DIR}"/credentials/admin
ADMIN_SRC_DIR="${PROJECT_DIR}"/src/admin

WEBPHP_CREDENTIALS_DIR="${PROJECT_DIR}"/credentials/webphp
WEBPHP_SRC_DIR="${PROJECT_DIR}"/src/webphp
