# aws-datacenter

Amazon Web Services datacenter.

Bash scripts that use AWS cli command line utility to deploy a datacenter on Amazon Web Services cloud.
Datacenter composition:

- a private Admin web site. 
- one of more instances of a public accessible web site.
- a load balancer that routes the traffic to the public web site.
- a relational database

The HTTPS certificates for the Load Balancer and the Admin web site are validated by Let's Encrypt CA.

Workspace: 

- Fedora 35
- GNU bash version 5.1.8
- AWS cli 2.4.3 
- Python/3.10.0 

## Required programs:
```
## Install the required programs: 

sudo dnf install -y expect openssl jq xmlstarlet

## Install the AWS CLI:

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

```

## Configure SSH:

edit: /etc/ssh/ssh_config, add the lines:

```
Host *
ServerAliveInterval 100

```

## Configure AWS CLI:
configure aws client with the keys of a IAM user with admin rights.
```
aws configure

```

## To create the datacenter:
```
cd aws-datacenter
amazon/master/make.sh

```

## To delete the datacenter:
```
cd aws-datacenter
amazon/master/delete.sh

```

## Configure reCaptcha:

The reCaptcha keys are in: recaptcha.sh.
Add the 'maxmin.it' domain to your Google account.

## Access the website:
 
https://www.maxmin.it

## Access the Admin website:

Enable access to the Admin website's 443 port in the security group.

https://admin.maxmin.it
(password is admin)

## Access the M/Monit website:

Enable access to the M/Monit website's 8443 port in the security group.

https://admin.maxmin.it:8443
(admin/swordfish)

## Access to PhpMyAdmin website:

Enable access to the PhpMyAdmin website's 7443 port in the security group.

https://admin.maxmin.it:7443/phpmyadmin/index.php
(maxmin/fognamarcia11)

## Access to Loganalyzer website:

Enable access to the Loganalyzer website's 9443 port in the security group.

https://admin.maxmin.it:9443/loganalyzer/index.php


