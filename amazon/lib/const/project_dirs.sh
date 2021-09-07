#!/usr/bin/bash 
 
# shellcheck disable=SC2034 

TMP_DIR="${PROJECT_DIR}"/temp
TEMPLATE_DIR="${PROJECT_DIR}"/templates
JAR_DIR="${PROJECT_DIR}"/jars
DOWNLOAD_DIR="${PROJECT_DIR}"/download
LOG_DIR="${PROJECT_DIR}"/logs

SHARED_INST_ACCESS_DIR="${PROJECT_DIR}"/access/shared

ADMIN_INST_ACCESS_DIR="${PROJECT_DIR}"/access/admin
ADMIN_INST_SRC_DIR="${PROJECT_DIR}"/src/admin

WEBPHP_INST_ACCESS_DIR="${PROJECT_DIR}"/access/webphp
WEBPHP_INST_SRC_DIR="${PROJECT_DIR}"/src/webphp

BOSH_ACCESS_DIR="${PROJECT_DIR}"/access/cloudfoundry
BOSH_WORK_DIR="${PROJECT_DIR}"/bosh
