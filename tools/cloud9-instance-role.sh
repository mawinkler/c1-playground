#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

# Check if AWS_REGION is set to desired region. The above curl to 169.254.269.254 points to
# an AWS internal url allowing an EC2 instance to query some information about itself without
# requiring a role for this. Feel free to play with it
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set

# Let’s save these into bash_profile
echo "export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}

# Next, we define some names:
ROLE_NAME=ekscluster-admin-$(openssl rand -hex 4)
INSTANCE_PROFILE_NAME=${ROLE_NAME}

# Create the policy for EC2 access
EC2_TRUST="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"Service\": \"ec2.amazonaws.com\"
      },
      \"Action\": \"sts:AssumeRole\"
    }
  ]
}"

# Create role, attach policy, create instance-profile and add role
aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document "${EC2_TRUST}" --output text --query 'Role.Arn'
aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
aws iam create-instance-profile --instance-profile-name ${INSTANCE_PROFILE_NAME}
aws iam add-role-to-instance-profile --role-name ${ROLE_NAME} --instance-profile-name ${INSTANCE_PROFILE_NAME}

# Which the following commands, we grant our Cloud9 instance the priviliges to manage an EKS cluster.
# Query the instance ID of our Cloud9 environment
INSTANCE_ID=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.instanceId')
# Attach the IAM role to an existing EC2 instance
aws ec2 associate-iam-instance-profile --instance-id ${INSTANCE_ID} --iam-instance-profile Name=${INSTANCE_PROFILE_NAME}

# To ensure temporary credentials aren’t already in place we will also remove any existing credentials file:
rm -vf ${HOME}/.aws/credentials

# Use the GetCallerIdentity CLI command to validate that the Cloud9 IDE is using the correct IAM role.
aws sts get-caller-identity --query Arn | grep ekscluster-admin -q && echo "IAM role valid" || echo "IAM role NOT valid"
aws sts get-caller-identity --query Arn
