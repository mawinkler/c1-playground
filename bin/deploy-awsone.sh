#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
AWS_ACCOUNT_ID="$(yq '.services[] | select(.name=="aws") | .account_id' $PGPATH/config.yaml)"
AWS_REGION="$(yq '.services[] | select(.name=="aws") | .region' $PGPATH/config.yaml)"
AWS_ENVIRONMENT="$(yq '.services[] | select(.name=="aws") | .environment' $PGPATH/config.yaml)"
ACCESS_IP="$(yq '.services[] | select(.name=="awsone") | .access_ip' $PGPATH/config.yaml)"
CREATE_LINUX="$(yq '.services[] | select(.name=="awsone") | .create_linux' $PGPATH/config.yaml)"
CREATE_WINDOWS="$(yq '.services[] | select(.name=="awsone") | .create_windows' $PGPATH/config.yaml)"

CLOUD_ONE_API_KEY="$(yq '.services[] | select(.name=="cloudone") | .api_key' $PGPATH/config.yaml)"
CLOUD_ONE_REGION="$(yq '.services[] | select(.name=="cloudone") | .region' $PGPATH/config.yaml)"
CLOUD_ONE_INSTANCE="$(yq '.services[] | select(.name=="cloudone") | .instance' $PGPATH/config.yaml)"
if [ ${CLOUD_ONE_INSTANCE} = null ]; then
  CLOUD_ONE_INSTANCE=cloudone
fi
CLOUD_ONE_POLICY_ID="$(yq '.services[] | select(.name=="container_security") | .policy_id' $PGPATH/config.yaml)"


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

  printf '%s\n' "Create terraform.tfvars for network"
  AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID} \
  AWS_REGION=${AWS_REGION} \
  AWS_ENVIRONMENT=${AWS_ENVIRONMENT} \
  ACCESS_IP=${ACCESS_IP} \
    envsubst <$PGPATH/templates/terraform-2-network.tfvars >$PGPATH/terraform-awsone/2-network/terraform.tfvars

  printf '%s\n' "Create terraform.tfvars for instances"
  AWS_REGION=${AWS_REGION} \
  ACCESS_IP=${ACCESS_IP} \
  AWS_ENVIRONMENT=${AWS_ENVIRONMENT} \
  CREATE_LINUX=${CREATE_LINUX} \
  CREATE_WINDOWS=${CREATE_WINDOWS} \
    envsubst <$PGPATH/templates/terraform-3-instances.tfvars >$PGPATH/terraform-awsone/3-instances/terraform.tfvars

  printf '%s\n' "Create terraform.tfvars for cluster"
  AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID} \
  AWS_REGION=${AWS_REGION} \
  AWS_ENVIRONMENT=${AWS_ENVIRONMENT} \
  ACCESS_IP=${ACCESS_IP} \
    envsubst <$PGPATH/templates/terraform-4-cluster.tfvars >$PGPATH/terraform-awsone/4-cluster/terraform.tfvars

  printf '%s\n' "Create terraform.tfvars for cluster deployments"
  AWS_ENVIRONMENT=${AWS_ENVIRONMENT} \
  CLOUD_ONE_API_KEY=${CLOUD_ONE_API_KEY} \
  CLOUD_ONE_REGION=${CLOUD_ONE_REGION} \
  CLOUD_ONE_INSTANCE=${CLOUD_ONE_INSTANCE} \
  CLOUD_ONE_POLICY_ID=${CLOUD_ONE_POLICY_ID} \
    envsubst <$PGPATH/templates/terraform-9-cluster-deployments.tfvars >$PGPATH/terraform-awsone/9-cluster-deployments/terraform.tfvars

  echo "💬 Terraform terraform.tfvars dropped to configurations"
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

  cd $PGPATH/terraform-awsone/2-network
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
