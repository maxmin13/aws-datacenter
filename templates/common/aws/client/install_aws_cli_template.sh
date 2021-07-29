#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###################################################################
# Install the AWS CLI version 2 on Linux. The AWS CLI version 2 
# has no dependencies on other Python packages. It has a 
# self-contained, embedded copy of Python included in the 
# installer.
###################################################################

AWS_CLI_REPOSITORY_URL='SEDaws_cli_repository_urlSED'
AWS_CLI_ARCHIVE='awscli-exe-linux-x86_64.zip'
AWS_CLI_SIGNATURE='awscli-exe-linux-x86_64.zip.sig'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${script_dir}" || exit

echo 'Installing AWS client ...'

curl "${AWS_CLI_REPOSITORY_URL}"/"${AWS_CLI_ARCHIVE}" -o awscliv2.zip

# Import the AWS CLI public key
gpg --import aws_cli_public_key

# Download the AWS CLI signature file for the package you downloaded.
curl -o awscliv2.sig ${AWS_CLI_REPOSITORY_URL}/${AWS_CLI_SIGNATURE}  -o awscliv2.sig

# Verify the signature.
# The warning in the output is expected and doesn't indicate a problem. It occurs because there 
# isn't a chain of trust between your personal PGP key (if you have one) and the AWS CLI PGP key.
set +e 
gpg --verify awscliv2.sig awscliv2.zip
exit_code=$?
set -e

if [[ 0 -eq "${exit_code}" ]]
then
   echo 'AWS client archive signature successfully verified.'
else
   echo 'ERROR: verifying AWS client signature.'
   exit 1
fi

# Install the client.
# By default, the files are all installed to /usr/local/aws-cli, and a symbolic link is 
# created in /usr/local/bin.
unzip awscliv2.zip -d aws-cli && cd aws-cli
./aws/install --update
aws --version

echo 'AWS client installed.'

exit 0
