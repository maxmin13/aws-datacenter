# aws-datacenter
Amazon Web Services datacenter.

Scripts to deploy on Amazon Web Services a datacenter, composed of:
- loadbalancer
- relational database
- Admin web site
- one or more public accessible web sites

Env: Linux Fedora distribution.

## Required programs:
```
## Install the required programs: 

sudo dnf install expect openssl xmlstarlet

## Install Java and add it in path.

## Install the AWS CLI:

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

```

## Configure the AWS CLI with the details of your account:
aws configure

## To create the datacenter:
```
cd datacenter
amazon/master/make.sh
```

## To delete the datacenter:
```
cd datacenter
amazon/master/delete.sh
```

## Configure reCaptcha:

The reCaptcha keys are in: recaptcha.sh
Add the 'maxmin.it' domain to your Google account.

## Access the website:
 
https://www.maxmin.it

## Access the Admin website:

Enable access to the Admin website's 443 port in the Security Group.

https://admin.maxmin.it
(password is admin)

## Access the M/Monit website:

Enable access to the M/Monit website's 8443 port in the Security Group.

https://admin.maxmin.it:8443
(admin/swordfish)

## Access to PhpMyAdmin website:

Enable access to the PhpMyAdmin website's 7443 port in the Security Group.

https://admin.maxmin.it:7443/phpmyadmin/index.php
(maxmin/fognamarcia11)

## Access to Loganalyzer website:

Enable access to the Loganalyzer website's 9443 port in the Security Group.

https://admin.maxmin.it:9443/loganalyzer/index.php


