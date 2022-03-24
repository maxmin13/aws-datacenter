# aws-datacenter

Amazon Web Services datacenter built with AWS cli command line utility.

Datacenter composition:

- a private Admin web site. 
- one of more instances of a public accessible web site.
- a load balancer that routes the traffic to the public web site.
- a relational database

The HTTPS certificates for the Load Balancer and the Admin web site are validated by Let's Encrypt CA.

A domain registration request is submitted to AWS for the domain maxmin13.it the first time the application
scripts are run. The cost of the domain registration is automatically billed to the current AWS account.

Workspace: 

- Fedora 35
- GNU bash version 5.1.8
- AWS cli 2.4.3 
- Python/3.10.0 

## Required local programs:
Log into your Fedora workstation
```
## Install the required programs: 

sudo dnf install -y expect openssl jq xmlstarlet

## Install the AWS CLI:

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

```

## Configure local SSH:

edit: /etc/ssh/ssh_config, add the lines:

```
Host *
ServerAliveInterval 100

```

## Configure local AWS CLI:
Configure aws client with the keys of a IAM user with admin rights.
```
aws configure

```

## Register a domain with AWS Route53 registrar:
Register the domain in app_consts.sh maxmin.it. with the current account:
```
amazon/dns/domain/registration/make.sh 
```
The registration of a domain take a few days.


## Create the application DNS hosted zone.
Create a new hosted zone for the domain in app_consts.sh maxmin.it:
```
amazon/dns/hostedzone/make.sh
```


## Create the AWS datacenter:
After domain and hosted zone have become operative, create the AWS datacenter (VPC) by running the script: 
```
cd aws-datacenter
amazon/run/make.sh

```

## To delete the datacenter:
```
cd aws-datacenter
amazon/run/delete.sh

```

## Configure reCaptcha:

The reCaptcha keys are in: recaptcha.sh.
Add the maxmin.it domain to your Google account.

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


#ref: Aws scripted by Christian Cerri
