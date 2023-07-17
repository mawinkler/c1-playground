#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
AWS_ACCOUNT_ID="$(yq '.services[] | select(.name=="aws") | .account_id' $PGPATH/config.yaml)"
AWS_REGION="$(yq '.services[] | select(.name=="aws") | .region' $PGPATH/config.yaml)"
AWSONE_WINDOWS_PASSWORD="$(yq '.services[] | select(.name=="awsone") | .windows_password' $PGPATH/config.yaml)"

mkdir -p $PGPATH/overrides

#######################################
# Create Terraform variables.tfvars
# Globals:
#   AWS_ACCOUNT_ID
#   AWSONE_WINDOWS_PASSWORD
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_tf_variables() {

  printf '%s\n' "Create terraform variables.tf"
  AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID} \
  AWS_REGION=${AWS_REGION} \
  AWSONE_WINDOWS_PASSWORD=${AWSONE_WINDOWS_PASSWORD} \
    envsubst <$PGPATH/templates/terraform-variables.tf >$PGPATH/terraform-awsone/terraform.tfvars

  echo "💬 Terraform variables.tf dropped to $PGPATH/terraform-awsone/terraform.tfvars"
}

#######################################
# Prepares a AWS based V1 & C1
# demo environment
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_environment() {

  cd $PGPATH/terraform-awsone

  terraform init
  # terraform apply 
  #-auto-approve
}

#######################################
# Main:
# Deploys a AWS based V1 & C1
# demo environment
#######################################
function main() {

  create_tf_variables
  create_environment
}

function cleanup() {
  return
  false
}

function test() {
  return
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi

printf '\n%s\n' "###TASK-COMPLETED###"
