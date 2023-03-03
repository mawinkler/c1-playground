#!/bin/bash

#######################################
# Requirements:
#   - If running on Cloud9:
#     - tools/cloud9-resize.sh
#     - tools/cloud9-instance-role.sh
#   - If running on Linux/Mac:
#     - aws configure
#   - clusters/rapid-eks.sh
#   - $PGPATH/bin/deploy-smartcheck.sh
#######################################

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Future use
API_KEY="$(yq '.services[] | select(.name=="cloudone") | .api_key' $PGPATH/config.yaml)"
REGION="$(yq '.services[] | select(.name=="cloudone") | .region' $PGPATH/config.yaml)"
INSTANCE="$(yq '.services[] | select(.name=="cloudone") | .instance' $PGPATH/config.yaml)"
if [ ${INSTANCE} = null ]; then
  INSTANCE=cloudone
fi

GITHUB_USERNAME="$(yq '.services[] | select(.name=="pipeline") | .github_username' $PGPATH/config.yaml)"
GITHUB_EMAIL="$(yq '.services[] | select(.name=="pipeline") | .github_email' $PGPATH/config.yaml)"
APP_NAME="$(yq '.services[] | select(.name=="pipeline") | .github_project' $PGPATH/config.yaml)"
TREND_AP_KEY="$(yq '.services[] | select(.name=="pipeline") | .appsec_key' $PGPATH/config.yaml)"
TREND_AP_SECRET="$(yq '.services[] | select(.name=="pipeline") | .appsec_secret' $PGPATH/config.yaml)"
DOCKER_USERNAME="$(yq '.services[] | select(.name=="pipeline") | .docker_username' $PGPATH/config.yaml)"
DOCKER_PASSWORD="$(yq '.services[] | select(.name=="pipeline") | .docker_password' $PGPATH/config.yaml)"
DSSC_USERNAME="$(yq '.services[] | select(.name=="smartcheck") | .username' $PGPATH/config.yaml)"
DSSC_PASSWORD="$(yq '.services[] | select(.name=="smartcheck") | .password' $PGPATH/config.yaml)"
DSSC_REGUSER="$(yq '.services[] | select(.name=="smartcheck") | .reg_username' $PGPATH/config.yaml)"
DSSC_REGPASSWORD="$(yq '.services[] | select(.name=="smartcheck") | .reg_password' $PGPATH/config.yaml)"

mkdir -p $PGPATH/overrides

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
if [ -f ~/.aws/config ]; then
  AWS_REGION=$(cat ~/.aws/config | sed -n 's/^region\s=\s\(.*\)/\1/p')
else
  AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
fi
printf '%s\n' "AWS Account ID: ${AWS_ACCOUNT_ID}"
printf '%s\n' "AWS Region: ${AWS_REGION}"

cat <<EOF >$PGPATH/bin/pipeline-aws-down.sh
set -e
EOF
chmod +x $PGPATH/bin/pipeline-aws-down.sh

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

    echo "aws iam delete-role-policy --role-name ${CODEBUILD_ROLE_NAME} --policy-name eks-describe-ecr-pull" >> $PGPATH/bin/pipeline-aws-down.sh
    echo "aws iam delete-role --role-name ${CODEBUILD_ROLE_NAME}" >> $PGPATH/bin/pipeline-aws-down.sh
  else
    printf '%s\n' "Using IAM Role "${CODEBUILD_ROLE_NAME}" for EKS"
  fi

  if [ $(kubectl get -n kube-system configmap/aws-auth -o json | jq -r '.data.mapRoles | contains("ekscluster-codebuild") | .') == false ]; then
    printf '%s\n' "Mapping role "${CODEBUILD_ROLE_NAME}" to cluster"
    ### Modify AWS-Auth ConfigMap
    ROLE="    - rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CODEBUILD_ROLE_NAME}\n      username: build\n      groups:\n        - system:masters"
    kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"${ROLE}\";next}1" > $PGPATH/aws-auth-patch.yml
    kubectl patch configmap/aws-auth -n kube-system --patch "$(cat $PGPATH/aws-auth-patch.yml)"
    rm -f $PGPATH/aws-auth-patch.yml
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
      <$PGPATH/templates/pipeline-aws-pipeline.cfn.yaml \
      >$PGPATH/overrides/${APP_NAME}-pipeline.cfn.yml
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
      --template-file $PGPATH/overrides/${APP_NAME}-pipeline.cfn.yml \
      --capabilities CAPABILITY_IAM

    echo "aws ecr delete-repository --repository-name ${APP_NAME} --force" >> $PGPATH/bin/pipeline-aws-down.sh
    echo "aws cloudformation delete-stack --stack-name ${APP_NAME}-pipeline" >> $PGPATH/bin/pipeline-aws-down.sh
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

    cp $PGPATH/templates/pipeline-aws-buildspec.yaml ./buildspec.yml
    IMAGE_NAME=${APP_NAME} \
      TREND_AP_KEY=${TREND_AP_KEY} \
      TREND_AP_SECRET=${TREND_AP_SECRET} \
      envsubst <$PGPATH/templates/pipeline-aws-app.yml > ./app-eks.yml
    
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
