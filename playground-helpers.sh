#!/bin/bash

function setup_smartcheck {

  SC_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .username' config.json)"
  SC_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .password' config.json)"
  SC_PORT="$(jq -r '.services[] | select(.name=="smartcheck") | .proxy_service_port' config.json)"
  SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
}

function get_smartcheck {

  setup_smartcheck
  
  # gke
  if [[ $(kubectl config current-context) =~ gke_.* ]]; then

    printf '%s\n' "running on gke"
    SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  # aks
  elif [[ $(kubectl config current-context) =~ .*-aks ]]; then

    printf '%s\n' "running on aks"
    SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  # eks
  elif [[ $(kubectl config current-context) =~ .*eksctl.io ]]; then

    printf '%s\n' "running on eks"
    printf '%s\n' "NOT YET IMPLEMENTED"
    exit 0

  # local
  else

    printf '%s\n' "running on local playground"
    if [ "${OS}" == 'Linux' ]; then
      SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
                    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi

    if [ "${OS}" == 'Darwin' ]; then
      SC_HOST="$(jq -r '.services[] | select(.name=="smartcheck") | .hostname' config.json)"
    fi

  fi
}

function get_registry {

  # gke
  if [[ $(kubectl config current-context) =~ gke_.* ]]; then

    printf '%s\n' "running on gke"
    GCP_HOSTNAME="gcr.io"
    GCP_PROJECTID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
    REGISTRY=${GCP_HOSTNAME}/${GCP_PROJECTID}

  # aks
  elif [[ $(kubectl config current-context) =~ .*-aks ]]; then

    printf '%s\n' "running on aks"
    PLAYGROUND_NAME="$(jq -r '.cluster_name' config.json)"

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
  elif [[ $(kubectl config current-context) =~ .*eksctl.io ]]; then

    printf '%s\n' "running on eks"
    printf '%s\n' "NOT YET IMPLEMENTED"
    exit 0

  # local
  else

    printf '%s\n' "running on local playground"
    REG_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' config.json)"
    REG_NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' config.json)"
    OS="$(uname)"

    if [ "${OS}" == 'Linux' ]; then

      REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"

    fi

    if [ "${OS}" == 'Darwin' ]; then

      REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                      -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"

    fi

    REGISTRY="${REG_HOST}:${REG_PORT}"

  fi
}
