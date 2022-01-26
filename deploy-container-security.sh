#!/bin/bash

set -e

# Source helpers
. ./playground-helpers.sh

# Get config
CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
CS_POLICY_NAME="$(jq -r '.services[] | select(.name=="container_security") | .policy_name' config.json)"
CS_NAMESPACE="$(jq -r '.services[] | select(.name=="container_security") | .namespace' config.json)"
SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
API_KEY="$(jq -r '.services[] | select(.name=="cloudone") | .api_key' config.json)"
REGION="$(jq -r '.services[] | select(.name=="cloudone") | .region' config.json)"

DEPLOY_RT=false
if is_gke || is_aks || is_eks ; then
  printf '%s\n' "Deploying with Runtime Security"
  DEPLOY_RT=true
fi

# Create API header
API_KEY=${API_KEY} envsubst <templates/cloudone-header.txt >overrides/cloudone-header.txt

#######################################
# Creates Kubernetes namespace
# Globals:
#   SC_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_namespace() {
  # create namespace
  printf '%s' "Create container security namespace"
  NAMESPACE=${CS_NAMESPACE} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# Container Security
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function whitelist_namsspaces() {
  # whitelist some namespace for container security
  kubectl label namespace kube-system --overwrite ignoreAdmissionControl=true
}

#######################################
# Checks for an already existing
# cluster policy. If there is not the
# desired one it gets created
# Globals:
#   REGION
#   CS_POLICY_NAME
#   REGISTRY
# Arguments:
#   None
# Outputs:
#   CS_POLICYID
#######################################
function cluster_policy() {
  # query cluster policy
  CS_POLICYID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.cloudone.trendmicro.com/api/policies' \
    --header @overrides/cloudone-header.txt |
      jq -r --arg CS_POLICY_NAME "${CS_POLICY_NAME}" '.policies[] | select(.name==$CS_POLICY_NAME) | .id'
  )
  # create policy if not exist
  if [ "${CS_POLICYID}" == "" ]; then
    get_registry
    printf '%s\n' "Registry is on ${REGISTRY}"

    cluster_rulesets

    RESULT=$(
      CS_POLICY_NAME=${CS_POLICY_NAME} \
        REGISTRY=${REGISTRY} \
        RULESETS_JSON=${RULESETS_JSON} \
        envsubst <templates/container-security-policy.json | \
          curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/policies' \
          --header @overrides/cloudone-header.txt \
          --data-binary "@-"
    )
    CS_POLICYID=$(echo ${RESULT} | jq -r ".id")
    printf '%s\n' "Policy with id ${CS_POLICYID} created"
  else
    printf '%s\n' "Reusing cluster policy with id ${CS_POLICYID}"
  fi
}

#######################################
# Checks for an already existing
# cluster policy. If there is not the
# desired one it gets created
# Globals:
#   REGION
#   CS_POLICY_NAME
#   REGISTRY
# Arguments:
#   None
# Outputs:
#   CS_POLICYID
#######################################
function cluster_rulesets() {
  RULESETS_JSON='"runtime":{"default":{"rulesets":['

  for ruleset in info notice warning critical error ; do
    # query cluster policy
    CS_RULESET_NAME=${CS_POLICY_NAME}_${ruleset}
    CS_RULESETID=$(
      curl --silent --location --request GET 'https://container.'${REGION}'.cloudone.trendmicro.com/api/rulesets' \
      --header @overrides/cloudone-header.txt |
        jq -r --arg CS_RULESET_NAME "${CS_RULESET_NAME}" '.rulesets[] | select(.name==$CS_RULESET_NAME) | .id'
    )
    # create policy if not exist
    if [ "${CS_RULESETID}" == "" ]; then
      RESULT=$(
        CS_RULESET_NAME=${CS_RULESET_NAME} \
          envsubst <templates/container-security-ruleset-${ruleset}.json | \
            curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/rulesets' \
            --header @overrides/cloudone-header.txt \
            --data-binary "@-"
      )
      CS_RULESETID=$(echo ${RESULT} | jq -r ".id")
      printf '%s\n' "Ruleset with id ${CS_RULESETID} created"
    else
      printf '%s\n' "Reusing ruleset with id ${CS_RULESETID}"
    fi

    RULESETS_JSON=${RULESETS_JSON}'{"name":"'${CS_RULESET_NAME}'","id":"'${CS_RULESETID}'"},'
  done

  RULESETS_JSON=${RULESETS_JSON::-1}']}}'
}

#######################################
# Creates cluster object in Container
# Security.
# Globals:
#   CLUSTER_NAME
#   CS_POLICYID
#   DEPLOY_RT
#   REGION
# Arguments:
#   None
# Outputs:
#   API_KEY_ADMISSION_CONTROLLER
#   CS_CLUSTERID
#   AP_KEY
#   AP_SECRET
#######################################
function create_cluster_object() {
  CLUSTER_ID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.cloudone.trendmicro.com/api/clusters' \
    --header @overrides/cloudone-header.txt | \
    jq -r --arg CLUSTER_NAME ${CLUSTER_NAME//-/_} '.clusters[] | select(.name==$CLUSTER_NAME) | .id'
  )
  if [ "${CLUSTER_ID}" != "" ] ; then
    printf '%s\n' "Reusing cluster object with id ${CLUSTER_ID}"
  else
    printf '%s\n' "Create cluster object"
    RESULT=$(
      CLUSTER_NAME=${CLUSTER_NAME//-/_} \
        CS_POLICYID=${CS_POLICYID} \
        DEPLOY_RT=${DEPLOY_RT} \
        envsubst <templates/container-security-cluster-object.json |
          curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/clusters' \
          --header @overrides/cloudone-header.txt \
          --data-binary "@-"
    )
    API_KEY_ADMISSION_CONTROLLER=$(echo ${RESULT} | jq -r ".apiKey")
    CS_CLUSTERID=$(echo ${RESULT} | jq -r ".id")
    AP_KEY=$(echo ${RESULT} | jq -r ".runtimeKey")
    AP_SECRET=$(echo ${RESULT} | jq -r ".runtimeSecret")
  fi
}

#######################################
# Deploys Container Security to
# Kubernetes
# Globals:
#   API_KEY_ADMISSION_CONTROLLER
#   DEPLOY_RT
#   CS_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_container_security() {
  ## deploy container security
  if [ -f "overrides/container-security-overrides.yaml" ] ; then
    printf '%s\n' "Reusing cluster existing cluster overrides"
  elif [ "${API_KEY_ADMISSION_CONTROLLER}" == "" ] ; then
    printf '%s\n' "Missing container security api key"
    exit 0
  else
    API_KEY_ADMISSION_CONTROLLER=${API_KEY_ADMISSION_CONTROLLER} \
      REGION=${REGION} \
      DEPLOY_RT=${DEPLOY_RT} \
      envsubst <templates/container-security-overrides.yaml >overrides/container-security-overrides.yaml
  fi

  printf '%s\n' "(Re-)deploy container security"
  helm upgrade \
    container-security \
    --values overrides/container-security-overrides.yaml \
    --namespace ${CS_NAMESPACE} \
    --install \
    https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz

  # if [[ $(kubectl config current-context) =~ gke_.*|aks-.*|.*eksctl.io ]]; then
  #   echo Running on GKE, AKS or EKS
  #   helm upgrade \
  #     container-security \
  #     --values overrides/container-security-overrides.yaml \
  #     --namespace ${CS_NAMESPACE} \
  #     --install \
  #     https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz
  # else
  #   # echo Not running on GKE, AKS or EKS
  #   helm template \
  #     container-security \
  #     --values overrides/container-security-overrides.yaml \
  #     --namespace ${CS_NAMESPACE} \
  #     https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz | \
  #       sed -e '/\s*\-\sname:\ FALCO_BPF_PROBE/,/\s*value:/d' | \
  #       kubectl --namespace ${CS_NAMESPACE} apply -f -
  # fi
}

#######################################
# Creates a Scanner in Container
# Security using a locally installed
# Smart Check
# Globals:
#   CLUSTER_NAME
#   REGION
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_scanner() {
  SCANNER_ID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.cloudone.trendmicro.com/api/scanners' \
    --header @overrides/cloudone-header.txt | \
    jq -r --arg CLUSTER_NAME ${CLUSTER_NAME//-/_} '.scanners[] | select(.name==$CLUSTER_NAME) | .id'
  )
  if [ "${SCANNER_ID}" != "" ] ; then
    printf '%s\n' "Reusing scanner with id ${SCANNER_ID}"
  fi
  if [ -f "overrides/container-security-overrides-image-security-bind.yaml" ] ; then
    printf '%s\n' "Reusing existing image security bind overrides"
  else
    printf '%s\n' "Create scanner object"
    RESULT=$(
      CLUSTER_NAME=${CLUSTER_NAME//-/_} \
        envsubst <templates/container-security-scanner.json |
          curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/scanners' \
          --header @overrides/cloudone-header.txt \
          --data-binary "@-"
    )
    # bind smartcheck to container security
    API_KEY_SCANNER=$(echo ${RESULT} | jq -r ".apiKey") \
      REGION=${REGION} \
      envsubst <templates/container-security-overrides-image-security-bind.yaml >overrides/container-security-overrides-image-security-bind.yaml
  fi

  # create scanner
  printf '%s\n' "(Re-)bind smartcheck to container security"
  helm upgrade \
    smartcheck \
    --reuse-values \
    --values overrides/container-security-overrides-image-security-bind.yaml \
    --namespace ${SC_NAMESPACE} \
    https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz >/dev/null
}

#######################################
# Main:
# Implements the Container Security
# deployment. Runtime Security is only
# activated on GKE, AKS or EKS
#######################################
function main() {
  create_namespace
  whitelist_namsspaces
  cluster_policy
  create_cluster_object
  deploy_container_security
  kubectl -n smartcheck get service proxy && create_scanner || echo Smartcheck not found
}

function cleanup() {
  printf '%s\n' "Get cluster id"
  CLUSTER_ID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.cloudone.trendmicro.com/api/clusters' \
    --header @overrides/cloudone-header.txt | \
    jq -r --arg CLUSTER_NAME ${CLUSTER_NAME//-/_} '.clusters[] | select(.name==$CLUSTER_NAME) | .id'
  )
  if [ "${CLUSTER_ID}" != "" ] ; then
    printf '%s\n' "Delete cluster ${CLUSTER_ID}"
    RESULT=$(
      curl --silent --location --request DELETE 'https://container.'${REGION}'.cloudone.trendmicro.com/api/clusters/'${CLUSTER_ID} \
      --header @overrides/cloudone-header.txt 
    )
  else
    printf '%s\n' "Cluster not found"
  fi
  printf '%s\n' "Get scanner id"
  SCANNER_ID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.cloudone.trendmicro.com/api/scanners' \
    --header @overrides/cloudone-header.txt | \
    jq -r --arg CLUSTER_NAME ${CLUSTER_NAME//-/_} '.scanners[] | select(.name==$CLUSTER_NAME) | .id'
  )
  if [ "${SCANNER_ID}" != "" ] ; then
    printf '%s\n' "Delete scanner ${SCANNER_ID}"
    RESULT=$(
      curl --silent --location --request DELETE 'https://container.'${REGION}'.cloudone.trendmicro.com/api/scanners/'${SCANNER_ID} \
      --header @overrides/cloudone-header.txt 
    )
  else
    printf '%s\n' "Scanner not found"
  fi

  helm -n ${CS_NAMESPACE} delete \
    container-security || true
  kubectl delete namespace ${CS_NAMESPACE}

  for i in {1..15} ; do
    sleep 2
    if [ "$(kubectl get all -n ${CS_NAMESPACE} | grep 'No resources found' || true)" == "" ] ; then
      return
    fi
  done
  false
}

function test() {
  for i in {1..10} ; do
    sleep 5
    # test deployments and pods
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -n ${CS_NAMESPACE} | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -n ${CS_NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    PODS_TOTAL=$(kubectl get pods -n ${CS_NAMESPACE} | wc -l)
    PODS_READY=$(kubectl get pods -n ${CS_NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    if [[ ( $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ) && ( $((${PODS_TOTAL} - 1)) -eq ${PODS_READY} ) ]] ; then
      echo ${DEPLOYMENTS_READY}
      return
    fi
  done
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi
