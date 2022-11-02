#!/bin/bash

# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.6.1.zip" \
#   -o "/tmp/awscliv2.zip"
# unzip /tmp/awscliv2.zip -d /tmp
# sudo /tmp/aws/install
# rm -Rf /tmp/aws /tmp/awscliv2.zip
# aws --version

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install --update
rm -Rf /tmp/aws /tmp/awscliv2.zip
