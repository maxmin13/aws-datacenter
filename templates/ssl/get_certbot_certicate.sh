#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

amazon-linux-extras install epel -y 

# Install snap.
yum install snapd

# The systemd unit that manages the main snap communication socket needs to be enabled.
systemctl enable --now snapd.socket

ln -s /var/lib/snapd/snap /snap

# Ensure that you have the latest version of snapd.
snap install core
snap refresh core

# Remove certbot-auto and any Certbot OS packages.
yum remove certbot

# Install certbot.
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# Get a certificate.
certbot certonly --apache

# The Certbot packages on your system come with a cron job or systemd timer that will renew 
# your certificates automatically before they expire. You will not need to run Certbot again, 
# unless you change your configuration. 
# The command to renew certbot is installed in one of the following locations:
# /etc/crontab/
# /etc/cron.*/*
# systemctl list-timers
# You can test automatic renewal for your certificates:

certbot renew --dry-run
amazon-linux-extras disable epel -y 


