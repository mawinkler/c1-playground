#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
CLUSTER_NAME="$(jq -r '.cluster_name' $PGPATH/config.json)"
CS_POLICY_NAME="$(jq -r '.services[] | select(.name=="container_security") | .policy_name' $PGPATH/config.json)"
CS_NAMESPACE="$(jq -r '.services[] | select(.name=="container_security") | .namespace' $PGPATH/config.json)"
SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' $PGPATH/config.json)"
API_KEY="$(jq -r '.services[] | select(.name=="cloudone") | .api_key' $PGPATH/config.json)"
REGION="$(jq -r '.services[] | select(.name=="cloudone") | .region' $PGPATH/config.json)"
INSTANCE="$(jq -r '.services[] | select(.name=="cloudone") | .instance' $PGPATH/config.json)"
if [ ${INSTANCE} = null ]; then
  INSTANCE=cloudone
fi

mkdir -p $PGPATH/overrides

# Create API header
API_KEY=${API_KEY} envsubst <$PGPATH/templates/cloudone-header.txt >$PGPATH/overrides/cloudone-header.txt

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
  NAMESPACE=${CS_NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
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
  kubectl label namespace ${CS_NAMESPACE} --overwrite ignoreAdmissionControl=true
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
  local policies=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/policies' \
    --header @$PGPATH/overrides/cloudone-header.txt
  )
  if ! check_response "$policies" ; then
    exit -1
  fi
  CS_POLICYID=$(jq -r --arg CS_POLICY_NAME "${CS_POLICY_NAME}" '.policies[] | select(.name==$CS_POLICY_NAME) | .id' <<< $policies)

  # create policy if not exist
  if [ "${CS_POLICYID}" == "" ]; then
    get_registry
    printf '%s\n' "Registry is on ${REGISTRY}"

    cluster_rulesets

    local result=$(
      CS_POLICY_NAME=${CS_POLICY_NAME} \
        REGISTRY=${REGISTRY} \
        RULESETS_JSON=${RULESETS_JSON} \
        envsubst <$PGPATH/templates/container-security-policy.json | \
          curl --silent --location --request POST 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/policies' \
          --header @$PGPATH/overrides/cloudone-header.txt \
          --data-binary "@-"
    )
    CS_POLICYID=$(jq -r ".id" <<< ${result})
    printf '%s\n' "Policy with id ${CS_POLICYID} created"
  else
    printf '%s\n' "Reusing cluster policy with id ${CS_POLICYID}"
  fi
}

#######################################
# Checks for an already existing
# runtime rulesets. If there are not the
# desired ones they get created
# Globals:
#   REGION
#   CS_POLICY_NAME
#   REGISTRY
# Arguments:
#   None
# Outputs:
#   RULESETS_JSON
#######################################
function cluster_rulesets() {
  RULESETS_JSON='"runtime":{"default":{"rulesets":['

  for ruleset in info notice warning critical error ; do
    # query cluster policy
    CS_RULESET_NAME=${CS_POLICY_NAME}_${ruleset}
    local rulesets=$(
      curl --silent --location --request GET 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/rulesets' \
      --header @$PGPATH/overrides/cloudone-header.txt
    )
    if ! check_response "$rulesets" ; then
      exit -1
    fi
    CS_RULESETID=$(jq -r --arg CS_RULESET_NAME "${CS_RULESET_NAME}" '.rulesets[] | select(.name==$CS_RULESET_NAME) | .id' <<< $rulesets)
    # create policy if not exist
    if [ "${CS_RULESETID}" == "" ]; then
      local result=$(
        CS_RULESET_NAME=${CS_RULESET_NAME} \
          envsubst <$PGPATH/templates/container-security-ruleset-${ruleset}.json | \
            curl --silent --location --request POST 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/rulesets' \
            --header @$PGPATH/overrides/cloudone-header.txt \
            --data-binary "@-"
      )
      CS_RULESETID=$(jq -r ".id" <<< $result)
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
#######################################
function create_cluster_object() {
  printf '%s\n' "Create cluster object"
  local result=$(
    CLUSTER_NAME=${CLUSTER_NAME//-/_}_$(openssl rand -hex 4) \
      CS_POLICYID=${CS_POLICYID} \
      envsubst <$PGPATH/templates/container-security-cluster-object.json |
        curl --silent --location --request POST 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/clusters' \
        --header @$PGPATH/overrides/cloudone-header.txt \
        --data-binary "@-"
  )
  API_KEY_ADMISSION_CONTROLLER=$(jq -r ".apiKey" <<< $result)
  CS_CLUSTERID=$(jq -r ".id" <<< $result)
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
  API_KEY_ADMISSION_CONTROLLER=${API_KEY_ADMISSION_CONTROLLER} \
    REGION=${REGION} \
    INSTANCE=${INSTANCE} \
    DEPLOY_RT=${DEPLOY_RT} \
    envsubst <$PGPATH/templates/container-security-overrides.yaml >$PGPATH/overrides/container-security-overrides.yaml

  printf '%s\n' "(Re-)deploy container security"
  curl -s -L https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz -o $PGPATH/master-cs.tar.gz
  helm upgrade \
    container-security \
    --values $PGPATH/overrides/container-security-overrides.yaml \
    --namespace ${CS_NAMESPACE} \
    --install \
    $PGPATH/master-cs.tar.gz
}

#######################################
# Main:
# Implements the Container Security
# deployment. Runtime Security is only
# activated on GKE, AKS or EKS
#######################################
function main() {
  DEPLOY_RT=false
  # if is_gke || is_aks || is_eks ; then
  #   printf '%s\n' "Deploying with Runtime Security"
  #   DEPLOY_RT=true
  # fi
  DEPLOY_RT=true
  create_namespace
  whitelist_namsspaces
  cluster_policy
  create_cluster_object
  deploy_container_security
}

function cleanup() {
  printf '%s\n' "Get cluster id"
  CLUSTER_ID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/clusters' \
    --header @$PGPATH/overrides/cloudone-header.txt | \
    jq -r --arg CLUSTER_NAME ${CLUSTER_NAME//-/_} '.clusters[] | select(.name==$CLUSTER_NAME) | .id'
  )
  if [ "${CLUSTER_ID}" != "" ] ; then
    printf '%s\n' "Delete cluster ${CLUSTER_ID}"
    RESULT=$(
      curl --silent --location --request DELETE 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/clusters/'${CLUSTER_ID} \
      --header @$PGPATH/overrides/cloudone-header.txt 
    )
  else
    printf '%s\n' "Cluster not found"
  fi
  printf '%s\n' "Get scanner id"
  SCANNER_ID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/scanners' \
    --header @$PGPATH/overrides/cloudone-header.txt | \
    jq -r --arg CLUSTER_NAME ${CLUSTER_NAME//-/_} '.scanners[] | select(.name==$CLUSTER_NAME) | .id'
  )
  if [ "${SCANNER_ID}" != "" ] ; then
    printf '%s\n' "Delete scanner ${SCANNER_ID}"
    RESULT=$(
      curl --silent --location --request DELETE 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/scanners/'${SCANNER_ID} \
      --header @$PGPATH/overrides/cloudone-header.txt 
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
  for i in {1..24} ; do
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
