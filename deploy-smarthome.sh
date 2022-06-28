#!/bin/bash

set -e

# Source helpers
. ./playground-helpers.sh

# Get config
NAMESPACE="$(jq -r '.services[] | select(.name=="smarthome") | .namespace' config.json)"
SERVICE_NAME="$(jq -r '.services[] | select(.name=="smarthome") | .proxy_service_name' config.json)"
LISTEN_PORT="$(jq -r '.services[] | select(.name=="smarthome") | .proxy_service_port' config.json)"

#######################################
# Creates Kubernetes namespace
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_namespace() {
  # create namespace
  printf '%s' "Create smarthome namespace"
  NAMESPACE=${NAMESPACE} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# smarthome
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function whitelist_namsspace() {
  # whitelist some namespace for container security
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=true
}

#######################################
# Deploys Smarthome to Kubernetes
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_smarthome() {
  ## deploy smarthome
  printf '%s\n' "deploy smarthome"

  helm repo add k8s-at-home https://k8s-at-home.com/charts/
  helm repo update

  mkdir -p overrides
  
  envsubst <templates/smarthome-homeassistant-overrides.yaml >overrides/smarthome-homeassistant-overrides.yaml

  # Install smarthome
  helm -n ${NAMESPACE} upgrade \
    homeassistant \
    --install \
    --values=overrides/smarthome-homeassistant-overrides.yaml \
    k8s-at-home/home-assistant
}

#######################################
# Creates Kubernetes ingress
# Globals:
#   SERVICE_NAME
#   NAMESPACE
#   HOSTNAME
#   LISTEN_PORT
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_ingress() {
  printf '%s\n' "Create smarthome ingress"
  SERVICE_NAME=${SERVICE_NAME} \
    NAMESPACE=${NAMESPACE} \
    HOSTNAME=${HOSTNAME} \
    LISTEN_PORT=${LISTEN_PORT} \
    envsubst <templates/smarthome-ingress.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "smarthome ingress created 🍻"
}

#######################################
# Main:
# Deploys smarthome
#######################################
function main() {
  echo "*** smarthome deployment currently in BETA ***"

  SERVICE_TYPE='LoadBalancer'

  create_namespace
  whitelist_namsspace
  deploy_smarthome

  if is_linux ; then
    # test if we're using a kind cluster and need a proxy
    if is_kind ; then
      ./deploy-proxy.sh smarthome
      echo "smarthome UI on: https://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}" | tee -a services
    fi
  fi
  # if is_darwin ; then
  #   create_ingress
  # fi
}

function cleanup() {
  helm -n ${NAMESPACE} delete \
    smarthome || true
  kubectl delete namespace ${NAMESPACE} || true
  
  for i in {1..10} ; do
    sleep 2
    if [ "$(kubectl get all -n ${NAMESPACE} | grep 'No resources found' || true)" == "" ] ; then
      return
    fi
  done
  false
}

function get_ui() {
  if is_kind ; then
    if is_linux ; then
      UI_URL="http://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}"
    else
      echo "*** smarthome currently not supported on MacOS ***"
    fi
  else
    if is_eks ; then
      UI_URL="http://$(kubectl -n ${NAMESPACE} get svc smarthome -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):${LISTEN_PORT}"
    else
      UI_URL="http://$(kubectl -n ${NAMESPACE} get svc smarthome -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):${LISTEN_PORT}"
    fi
  fi
}

function test() {
  for i in {1..20} ; do
    sleep 5
    # test deployments and pods
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -n ${NAMESPACE} | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -n ${NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    PODS_TOTAL=$(kubectl get pods -n ${NAMESPACE} | wc -l)
    PODS_READY=$(kubectl get pods -n ${NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    if [[ ( $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ) && ( $((${PODS_TOTAL} - 1)) -eq ${PODS_READY} ) ]] ; then
      echo ${DEPLOYMENTS_READY}
      # test web app
      get_ui
      echo ${UI_URL}
      for i in {1..10} ; do
        sleep 2
        if [ $(curl --write-out '%{http_code}' --silent --output /dev/null ${UI_URL} -eq 200) ] ; then
          return
        fi
      done
      return
    fi
  done
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi