#!/bin/bash

#######################################
# Requirements:
#   - ./tools.sh
#   - If running on Cloud9:
#     - tools/cloud9-resize.sh
#     - tools/cloud9-instance-role.sh
#   - If running on Linux/Mac:
#     - aws configure
#   - clusters/rapid-eks.sh
#   - ./deploy-smartcheck.sh
#######################################

set -e

# Source helpers
. ./playground-helpers.sh

# Future use
STAGING=false
if [ "${STAGING}" = true ]; then
  API_KEY="$(jq -r '.services[] | select(.name=="staging-cloudone") | .api_key' config.json)"
  REGION="$(jq -r '.services[] | select(.name=="staging-cloudone") | .region' config.json)"
  INSTANCE="$(jq -r '.services[] | select(.name=="staging-cloudone") | .instance' config.json)"
else
  API_KEY="$(jq -r '.services[] | select(.name=="cloudone") | .api_key' config.json)"
  REGION="$(jq -r '.services[] | select(.name=="cloudone") | .region' config.json)"
  INSTANCE="$(jq -r '.services[] | select(.name=="cloudone") | .instance' config.json)"
fi
# /

GITHUB_USERNAME="$(jq -r '.services[] | select(.name=="pipeline") | .github_username' config.json)"
GITHUB_EMAIL="$(jq -r '.services[] | select(.name=="pipeline") | .github_email' config.json)"
APP_NAME="$(jq -r '.services[] | select(.name=="pipeline") | .github_project' config.json)"
TREND_AP_KEY="$(jq -r '.services[] | select(.name=="pipeline") | .appsec_key' config.json)"
TREND_AP_SECRET="$(jq -r '.services[] | select(.name=="pipeline") | .appsec_secret' config.json)"
DOCKER_USERNAME="$(jq -r '.services[] | select(.name=="pipeline") | .docker_username' config.json)"
DOCKER_PASSWORD="$(jq -r '.services[] | select(.name=="pipeline") | .docker_password' config.json)"
DSSC_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .username' config.json)"
DSSC_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .password' config.json)"
DSSC_REGUSER="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_username' config.json)"
DSSC_REGPASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_password' config.json)"

mkdir -p overrides

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
if [ -f ~/.aws/config ]; then
  AWS_REGION=$(cat ~/.aws/config | sed -n 's/^region\s=\s\(.*\)/\1/p')
else
  AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
fi
printf '%s\n' "AWS Account ID: ${AWS_ACCOUNT_ID}"
printf '%s\n' "AWS Region: ${AWS_REGION}"

cat <<EOF >pipeline-aws-down.sh
set -e
EOF
chmod +x pipeline-aws-down.sh

#######################################
# Create IAM Role for EKS
# Globals:
#   AWS_ACCOUNT_ID
#   AWS_REGION
# Arguments:
#   None
# Outputs:
#   CODEBUILD_ROLE_NAME
#######################################
function create_iam_role_eks() {
  CODEBUILD_ROLE_NAME=$(aws iam list-roles | jq -r '.Roles[] | select(.RoleName|startswith("ekscluster-codebuild")) | .RoleName')
  if [ -z "${CODEBUILD_ROLE_NAME}" ]; then
    printf '%s\n' "Creating IAM Role for EKS"
    CODEBUILD_ROLE_NAME=ekscluster-codebuild-$(openssl rand -hex 4)
    TRUST='{
      "Version": "2012-10-17",
      "Statement": [ 
        {
          "Effect": "Allow",
          "Principal": { "AWS": "arn:aws:iam::'${AWS_ACCOUNT_ID}':root" }, "Action": "sts:AssumeRole"
        }
      ]
    }'

    aws iam create-role \
      --role-name ${CODEBUILD_ROLE_NAME} \
      --assume-role-policy-document "${TRUST}" \
      --output text \
      --query 'Role.Arn'
    aws iam put-role-policy \
    --role-name ${CODEBUILD_ROLE_NAME} \
    --policy-name eks-describe-ecr-pull \
    --policy-document file://templates/pipeline-aws-iam-role-policy.json

    echo "aws iam delete-role-policy --role-name ${CODEBUILD_ROLE_NAME} --policy-name eks-describe-ecr-pull" >> pipeline-aws-down.sh
    echo "aws iam delete-role --role-name ${CODEBUILD_ROLE_NAME}" >> pipeline-aws-down.sh
  else
    printf '%s\n' "Using IAM Role "${CODEBUILD_ROLE_NAME}" for EKS"
  fi

  if [ $(kubectl get -n kube-system configmap/aws-auth -o json | jq -r '.data.mapRoles | contains("ekscluster-codebuild") | .') == false ]; then
    printf '%s\n' "Mapping role "${CODEBUILD_ROLE_NAME}" to cluster"
    ### Modify AWS-Auth ConfigMap
    ROLE="    - rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CODEBUILD_ROLE_NAME}\n      username: build\n      groups:\n        - system:masters"
    kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"${ROLE}\";next}1" > aws-auth-patch.yml
    kubectl patch configmap/aws-auth -n kube-system --patch "$(cat aws-auth-patch.yml)"
    rm -f aws-auth-patch.yml
  else
    printf '%s\n' "Role "${CODEBUILD_ROLE_NAME}" already mapped"
  fi

}

#######################################
# Create the CloudFormation template
# Globals:
#   GITHUB_USERNAME
#   GITHUB_EMAIL
#   APP_NAME
#   AWS_REGION
#   AWS_ACCOUNT_ID
#   DSSC_USERNAME
#   DSSC_PASSWORD
#   DSSC_REGUSER
#   DSSC_REGPASSWORD
#   CODEBUILD_ROLE_NAME
#   TREND_AP_KEY
#   TREND_AP_SECRET
#   DOCKER_USERNAME
#   DOCKER_PASSWORD
# Arguments:
#   None
# Outputs:
#   overrides/${APP_NAME}-pipeline.cfn.yml
#######################################
function create_cloudformation() {
  printf '%s\n' "Creating CloudFormation Template"

  get_smartcheck

  AWS_REGION=${AWS_REGION} \
    IMAGE_NAME=${APP_NAME} \
    DSSC_HOST=${SC_HOST} \
    DSSC_USERNAME=${DSSC_USERNAME} \
    DSSC_PASSWORD=${DSSC_PASSWORD} \
    DSSC_REGUSER=${DSSC_REGUSER} \
    DSSC_REGPASSWORD=${DSSC_REGPASSWORD} \
    CODEBUILD_ROLE_NAME=${CODEBUILD_ROLE_NAME} \
    CLUSTER_NAME=$(eksctl get cluster -o json | jq -r '.[].Name') \
    TREND_AP_KEY=${TREND_AP_KEY} \
    TREND_AP_SECRET=${TREND_AP_SECRET} \
    DOCKER_USERNAME=${DOCKER_USERNAME} \
    DOCKER_PASSWORD=${DOCKER_PASSWORD} \
    AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID} \
    CODEBUILD_ROLE_NAME=$(aws iam list-roles | jq -r '.Roles[] | select(.RoleName|startswith("ekscluster-codebuild")) | .RoleName') \
    envsubst '$AWS_REGION,$IMAGE_NAME,$DSSC_HOST,$DSSC_USERNAME,$DSSC_PASSWORD,$DSSC_REGUSER,$DSSC_REGPASSWORD,$CODEBUILD_ROLE_NAME,$CLUSTER_NAME,$TREND_AP_KEY,$TREND_AP_SECRET,$DOCKER_USERNAME,$DOCKER_PASSWORD,$AWS_ACCOUNT_ID,$CODEBUILD_ROLE_NAME' \
      <templates/pipeline-aws-pipeline.cfn.yaml \
      >overrides/${APP_NAME}-pipeline.cfn.yml
}

#######################################
# Deploy the CloudFormation template
# Globals:
#   APP_NAME
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_cloudformation() {
  # Validate
  # aws cloudformation validate-template \
  #   --template-body file://overrides/${APP_NAME}-pipeline.cfn.yml

  # aws cloudformation list-stacks | jq -r '.StackSummaries[] | select(.StackName=="c1-app-sec-uploader-pipeline") | .StackStatus'

  if [ -z $(aws cloudformation describe-stacks --output json --region eu-central-1 | jq -r --arg app "${APP_NAME}" '.Stacks[] | select(.StackName | contains($app)) | .StackName') ]; then
    printf '%s\n' "Deploy CloudFormation Template"
    aws cloudformation deploy \
      --stack-name ${APP_NAME}-pipeline \
      --template-file overrides/${APP_NAME}-pipeline.cfn.yml \
      --capabilities CAPABILITY_IAM

    echo "aws ecr delete-repository --repository-name ${APP_NAME} --force" >> pipeline-aws-down.sh
    echo "aws cloudformation delete-stack --stack-name ${APP_NAME}-pipeline" >> pipeline-aws-down.sh
  else
    printf '%s\n' "CloudFormation Stack already exists"
  fi
}

#######################################
# Prepare the CodeCommit Repository
# Globals:
#   GITHUB_USERNAME
#   GITHUB_EMAIL
#   APP_NAME
#   AWS_REGION
#   TREND_AP_KEY
#   TREND_AP_SECRET
# Arguments:
#   None
# Outputs:
#   None
#######################################
function prepare_codecommit_repo() {
  printf '%s\n' "Preparing the CodeCommit Repository"

  if [ ! -d ${APP_NAME} ]; then
    git clone https://github.com/${GITHUB_USERNAME}/${APP_NAME}.git
    cd ${APP_NAME}
    git init
    git remote add aws https://git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${APP_NAME}

    git config --global user.email "${GITHUB_EMAIL}"
    git config --global user.name "${GITHUB_USERNAME}"

    cp ../templates/pipeline-aws-buildspec.yaml ./buildspec.yml
    IMAGE_NAME=${APP_NAME} \
      TREND_AP_KEY=${TREND_AP_KEY} \
      TREND_AP_SECRET=${TREND_AP_SECRET} \
      envsubst <../templates/pipeline-aws-app.yml > ./app-eks.yml
    
    # Enable the credential helper for git to modify `~/.gitconfig`
    git config --global credential.helper '!aws codecommit credential-helper $@'
    git config --global credential.UseHttpPath true

    cd ..
  else
    printf '%s\n' "Local Repository already exists"
  fi
}

#######################################
# Populate the CodeCommit Repository
# Globals:
#   APP_NAME
# Arguments:
#   None
# Outputs:
#   None
#######################################
function populate_codecommit_repo() {
  printf '%s\n' "Populating the CodeCommit Repository"

  cd ${APP_NAME}

  git add .
  git commit . -m "initial commit"
  git push aws main

  cd ..
}

function main() {

  if is_eks ; then
    create_iam_role_eks
    create_cloudformation
    deploy_cloudformation
    prepare_codecommit_repo
    populate_codecommit_repo
  else
    printf '%s\n' "Script requires an EKS cluster"
    exit 0
  fi
  echo "Run pipeline-aws-down.sh to tear down everything"
}

function cleanup() {
  printf '%s\n' "Not implemented"
  exit 0
}

function test() {
  printf '%s\n' "Not implemented"
  exit 0
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi
