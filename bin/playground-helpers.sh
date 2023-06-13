#!/bin/bash

# if [ "$PGPATH" == "" ]; then
#   echo PGPATH not set
#   exit 0
# fi

# if [[ ! "$PATH" =~ .*playground/bin.* ]]; then
#   echo $PGPATH/bin not in PATH
#   exit 0
# fi

#######################################
# Test for GKE cluster
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0: if GKE
#   false: if not GKE
#######################################
function is_gke() {
  if [[ $(kubectl config current-context) =~ gke_.* ]]; then
    return
  fi
  false
}

#######################################
# Test for AKS cluster
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0: if AKS
#   false: if not AKS
#######################################
function is_aks() {
  if [[ $(kubectl config current-context) =~ .*-aks ]]; then
    return
  fi
  false
}

#######################################
# Test for EKS cluster
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0: if EKS
#   false: if not EKS
#######################################
function is_eks() {
  if [[ $(kubectl config current-context) =~ arn:aws:eks:* ]] || [[ $(kubectl config current-context) =~ .*eksctl.io ]]; then
    return
  fi
  false
}

#######################################
# Test for EC2 instance
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0: if EC2
#   false: if not EC2
#######################################
function is_ec2() {
  if [[ $(curl -sS http://169.254.169.254/latest/meta-data/instance-id 2> /dev/null) =~ i-* ]]; then
    return
  fi
  false
}

#######################################
# Test for Kind cluster
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0: if Kind
#   false: if not Kind
#######################################
function is_kind() {
  if [[ $(kubectl config current-context) =~ kind.* ]]; then
    return
  fi
  false
}

#######################################
# Test for host operating system Linux
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0: if Linux
#   false: if not Linux
#######################################
function is_linux() {
  if [ "$(uname)" == 'Linux' ]; then
    return
  fi
  false
}

#######################################
# Test for host operating system Darwin
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0: if Darwin
#   false: if not Darwin
#######################################
function is_darwin() {
  if [ "$(uname)" == 'Darwin' ]; then
    return
  fi
  false
}

#######################################
# Retrieves the url of the registry
# Globals:
#   GCP_HOSTNAME
#   GCP_PROJECTID
#   PLAYGROUND_NAME
#   REGISTRY_NAME
#   REG_NAMESPACE
#   REG_NAME
# Arguments:
#   None
# Outputs:
#   REGISTRY
#######################################
function get_registry() {
  # gke
  if is_gke ; then
    GCP_HOSTNAME="gcr.io"
    GCP_PROJECTID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
    REGISTRY=${GCP_HOSTNAME}/${GCP_PROJECTID}
  # aks
  elif is_aks ; then
    PLAYGROUND_NAME="$(yq '.cluster_name' $PGPATH/config.yaml)"
    if [[ $(az group list | jq -r --arg PLAYGROUND_NAME ${PLAYGROUND_NAME} '.[] | select(.name==$PLAYGROUND_NAME) | .name') == "" ]]; then
      printf '%s\n' "creating resource group ${PLAYGROUND_NAME}"
      az group create --name ${PLAYGROUND_NAME} --location westeurope
    else
      printf '%s\n' "using resource group ${PLAYGROUND_NAME}"
    fi
    REGISTRY_NAME=$(az acr list --resource-group ${PLAYGROUND_NAME} | jq -r --arg PLAYGROUND_NAME ${PLAYGROUND_NAME//-/} '.[] | select(.name | startswith($PLAYGROUND_NAME)) | .name')
    if [[ ${REGISTRY_NAME} == "" ]]; then
      REGISTRY_NAME=${PLAYGROUND_NAME//-/}$(openssl rand -hex 4)
      printf '%s\n' "creating container registry ${REGISTRY_NAME}"
      az acr create --resource-group ${PLAYGROUND_NAME} --name ${REGISTRY_NAME} --sku Basic
    else
      printf '%s\n' "using container registry ${REGISTRY_NAME}"
    fi
    REGISTRY=$(az acr show --resource-group ${PLAYGROUND_NAME} --name ${REGISTRY_NAME} -o json | jq -r '.loginServer')
  # eks
  elif is_eks ; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
    AWS_REGION=$(aws configure get region)
    REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    printf '%s\n' "Using container registry ${REGISTRY}"
  # local
  else
    REG_NAME="$(yq '.services[] | select(.name=="playground-registry") | .name' $PGPATH/config.yaml)"
    REG_NAMESPACE="$(yq '.services[] | select(.name=="playground-registry") | .namespace' $PGPATH/config.yaml)"
    if is_linux ; then
      REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      REG_PORT="$(yq '.services[] | select(.name=="playground-registry") | .port' $PGPATH/config.yaml)"
    fi
    if is_darwin ; then
      REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                      -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      REG_PORT="$(yq '.services[] | select(.name=="playground-registry") | .port' $PGPATH/config.yaml)"
    fi
    REGISTRY="${REG_HOST}:${REG_PORT}"
  fi
}

#######################################
# Retrieves the username, password,
# and url of the registry
# Globals:
#   GCP_HOSTNAME
#   GCP_PROJECTID
#   PLAYGROUND_NAME
#   REGISTRY_NAME
#   REG_NAMESPACE
#   REG_NAME
# Arguments:
#   None
# Outputs:
#   REGISTRY
#   REGISTRY_USERNAME
#   REGISTRY_PASSWORD
#######################################
function get_registry_credentials() {

  get_registry

  # gke
  if is_gke ; then
    GCP_HOSTNAME="gcr.io"
    GCP_PROJECTID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
    printf '%s\n' "GCP Project is ${GCP_PROJECTID}"
    GCR_SERVICE_ACCOUNT=service-gcrsvc
    if test -f "${GCR_SERVICE_ACCOUNT}_keyfile.json"; then
      printf '%s\n' "Using existing key file"
    else
      printf '%s\n' "Creating Service Account"
      echo ${GCR_SERVICE_ACCOUNT}_keyfile.json
      gcloud iam service-accounts create ${GCR_SERVICE_ACCOUNT}
      gcloud projects add-iam-policy-binding ${GCP_PROJECTID} --member "serviceAccount:${GCR_SERVICE_ACCOUNT}@${GCP_PROJECTID}.iam.gserviceaccount.com" --role "roles/storage.admin"
      gcloud iam service-accounts keys create ${GCR_SERVICE_ACCOUNT}_keyfile.json --iam-account ${GCR_SERVICE_ACCOUNT}@${GCP_PROJECTID}.iam.gserviceaccount.com
    fi
    REGISTRY_USERNAME="_json_key"
    REGISTRY_PASSWORD=$(cat ${GCR_SERVICE_ACCOUNT}_keyfile.json | jq tostring)
  # aks
  elif is_aks ; then
    az acr update -n ${REGISTRY} --admin-enabled true 1>/dev/null
    ACR_CREDENTIALS=$(az acr credential show --name ${REGISTRY})
    REGISTRY_USERNAME=$(jq -r '.username' <<< $ACR_CREDENTIALS)
    REGISTRY_PASSWORD=$(jq -r '.passwords[] | select(.name=="password") | .value' <<< $ACR_CREDENTIALS)
  # eks
  elif is_eks ; then
    REGISTRY_USERNAME="AWS"
    REGISTRY_PASSWORD=$(aws ecr get-login-password --region ${AWS_REGION})
  # local
  else
    REGISTRY_USERNAME="$(yq '.services[] | select(.name=="playground-registry") | .username' $PGPATH/config.yaml)"
    REGISTRY_PASSWORD="$(yq '.services[] | select(.name=="playground-registry") | .password' $PGPATH/config.yaml)"
  fi
}

#######################################
# Retrieves the current kubernetes
# context if it exists.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Cluster context
#######################################
function check_k8s() {
    if $(kubectl config current-context &>/dev/null); then
        CLUSTER=$(kubectl config current-context)
    else
        CLUSTER="No Cluster"
    fi
}

#######################################
# Checks a returned JSON response if
# there is a message indicating a
# failure.
# Globals:
#   None
# Arguments:
#   $1 JSON
# Outputs:
#   0: if there is no message
#   message: if existant
#######################################
function check_response() {
  CHECK_ERR=$(jq -r '.message' <<< $1)
  if [ "${CHECK_ERR}" == "null" ]; then
    return
  fi
  echo ${CHECK_ERR}
  false
}

#######################################
# Checks the Cloud One API
# Configuration
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   CLUSTER
#######################################
function check_cloudone() {
  API_KEY="$(yq '.services[] | select(.name=="cloudone") | .api_key' $PGPATH/config.yaml)"
  REGION="$(yq '.services[] | select(.name=="cloudone") | .region' $PGPATH/config.yaml)"
  INSTANCE="$(yq '.services[] | select(.name=="cloudone") | .instance' $PGPATH/config.yaml)"
  if [ ${INSTANCE} = null ]; then
    INSTANCE=cloudone
  fi
  
  mkdir -p $PGPATH/overrides
  
  API_KEY=${API_KEY} envsubst <$PGPATH/templates/cloudone-header.txt >$PGPATH/overrides/cloudone-header.txt
  
  local clusters=$(curl --silent --location --request GET 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/clusters' \
      --header @$PGPATH/overrides/cloudone-header.txt)
  if check_response "$clusters" ; then
    return
  fi
  false
}

#######################################
# Retrieves the default editor
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   EDITOR
#######################################
function get_editor() {
  if [ -f $PGPATH/config.yaml ]; then
    EDITOR="$(yq '.editor' $PGPATH/config.yaml)"
  fi
  if [ "${EDITOR}" == "" ] || [ "${EDITOR}" == "null" ]; then
    if command -v nano &>/dev/null; then
        EDITOR=nano
    elif command -v vim &>/dev/null; then
        EDITOR=vim
    elif command -v vi &>/dev/null; then
        EDITOR=vi
    else
        echo No editor found. Aborting.
    fi
  fi
  echo Editor: ${EDITOR}
}
