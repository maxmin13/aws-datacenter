# aws-datacenter
Amazon Web Services datacenter.

Scripts to deploy on Amazon Web Services a datacenter, composed of:
- loadbalancer
- relational database
- Admin web site
- one or more public accessible web sites

The scripts need the AWS Command Line Interface (AWS CLI) installed:

## Install the AWS CLI:
- curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
- unzip awscliv2.zip
- sudo ./aws/install
- aws --version

## Configure the AWS CLI with the details of your account:
aws configure

cd datacenter/

## To create the datacenter:
amazon/master/make.sh

## To delete the datacenter:
amazon/master/delete.sh
