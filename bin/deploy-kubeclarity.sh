#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
NAMESPACE="$(yq '.services[] | select(.name=="kubeclarity") | .namespace' $PGPATH/config.yaml)"
SERVICE_NAME="$(yq '.services[] | select(.name=="kubeclarity") | .proxy_service_name' $PGPATH/config.yaml)"
LISTEN_PORT="$(yq '.services[] | select(.name=="kubeclarity") | .proxy_service_port' $PGPATH/config.yaml)"
PROXY_LISTEN_PORT="$(yq '.services[] | select(.name=="kubeclarity") | .proxy_listen_port' $PGPATH/config.yaml)"

SERVICE_TYPE="LoadBalancer"

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
  printf '%s' "Create kubeclarity namespace"
  NAMESPACE=${NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# Kubeclarity
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
# Deploys Kubeclarity to Kubernetes
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_kubeclarity() {
  ## deploy kubeclarity
  printf '%s\n' "deploy kubeclarity"

  helm repo add kubeclarity https://openclarity.github.io/kubeclarity
  helm repo update

  mkdir -p $PGPATH/overrides
  SERVICE_TYPE=${SERVICE_TYPE} \
    envsubst <$PGPATH/templates/kubeclarity-overrides.yaml >$PGPATH/overrides/kubeclarity-overrides.yaml

  # Install Kubeclarity
  helm -n ${NAMESPACE} upgrade \
    kubeclarity \
    --install \
    --values=$PGPATH/overrides/kubeclarity-overrides.yaml \
    kubeclarity/kubeclarity
}

#######################################
# Main:
# Deploys kubeclarity/kubeclarity
#######################################
function main() {
  create_namespace
  whitelist_namsspace
  deploy_kubeclarity

  if is_linux ; then
    # test if we're using a kind cluster and need a proxy
    if is_kind ; then
      $PGPATH/bin/deploy-proxy.sh kubeclarity
      echo "KUBEClarity: https://$(hostname -I | awk '{print $1}'):${PROXY_LISTEN_PORT}" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
    fi
  fi
}

function cleanup() {
  helm -n ${NAMESPACE} delete \
    kubeclarity || true
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
      echo "*** kubeclarity currently not supported on MacOS ***"
    fi
  else
    if is_eks ; then
      UI_URL="http://$(kubectl -n ${NAMESPACE} get svc kubeclarity-kubeclarity -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):${LISTEN_PORT}"
    else
      UI_URL="http://$(kubectl -n ${NAMESPACE} get svc kubeclarity-kubeclarity -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):${LISTEN_PORT}"
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

printf '\n%s\n' "###TASK-COMPLETED###"
