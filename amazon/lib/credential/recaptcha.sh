#!/usr/bin/bash

# shellcheck disable=SC2034

# Recaptcha keys:
# for the key to work via the ELB domain name
# you need to add amazonaws.com to the domains list

# The loadbanancer DNS name has to be added in google recaptcha to the list of
# the allowed domains for this keys.
RECAPTCHA_PRIVATE_KEY='6Lcam8gaAAAAABN2wuJGM9Y2gJwbMK4OgIMXf2Ki'
RECAPTCHA_PUBLIC_KEY='6Lcam8gaAAAAAJEiMxTHraaIfZy5YSa-b4Zt30uU'
