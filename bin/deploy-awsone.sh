#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
WS_TENANT_ID="$(yq '.services[] | select(.name=="cloudone") | .ws_tenant_id' $PGPATH/config.yaml)"
WS_TOKEN="$(yq '.services[] | select(.name=="cloudone") | .ws_token' $PGPATH/config.yaml)"
WS_POLICY_ID="$(yq '.services[] | select(.name=="cloudone") | .ws_policy_id' $PGPATH/config.yaml)"
V1_XBC_AGENT_URL="$(yq '.services[] | select(.name=="visionone") | .xbc_agent_url' $PGPATH/config.yaml)"

mkdir -p $PGPATH/overrides

#######################################
# Create DSA deployment script
# Globals:
#   WS_TENANT_ID
#   WS_TOKEN
#   WS_POLICY_ID
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_dsa_deployment_script() {

  printf '%s\n' "Create agent deployment script"
  cp $PGPATH/templates/terraform-dsa.sh $PGPATH/terraform-awsone/scripts/dsa.sh
  WS_TENANT_ID=${WS_TENANT_ID} \
    WS_TOKEN=${WS_TOKEN} \
    WS_POLICY_ID=${WS_POLICY_ID} \
    echo '/opt/ds_agent/dsa_control -a $ACTIVATIONURL "tenantID:'${WS_TENANT_ID}'" "token:'${WS_TOKEN}'" "policyid:'${WS_POLICY_ID}'"' >> $PGPATH/terraform-awsone/scripts/dsa.sh

  echo "💬 Agent deployment script dropped to $PGPATH/terraform-awsone/scripts/dsa.sh"
}

#######################################
# Create Terraform variables.tf
# Globals:
#   V1_XBC_AGENT_URL
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_tf_variables() {

  printf '%s\n' "Create terraform variables.tf"
  V1_XBC_AGENT_URL=${V1_XBC_AGENT_URL} \
    envsubst <$PGPATH/templates/terraform-variables.tf >$PGPATH/terraform-awsone/variables.tf

  echo "💬 Terraform variables.tf dropped to $PGPATH/terraform-awsone/variables.tf"
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

  if [ -f $PGPATH/terraform-awsone/cnctraining-key-pair ]; then
      printf '%s\n' "Reusing keypair"
  else
      ssh-keygen -f cnctraining-key-pair -q -N ""
  fi

  # terraform init
  # terraform apply -auto-approve
}

#######################################
# Main:
# Deploys a AWS based V1 & C1
# demo environment
#######################################
function main() {

  create_dsa_deployment_script
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
