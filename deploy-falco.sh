#!/bin/bash

set -e

# Source helpers
. ./playground-helpers.sh

# Get config
NAMESPACE="$(jq -r '.services[] | select(.name=="falco") | .namespace' config.json)"
HOSTNAME="$(jq -r '.services[] | select(.name=="falco") | .hostname' config.json)"
SERVICE_NAME="$(jq -r '.services[] | select(.name=="falco") | .proxy_service_name' config.json)"
LISTEN_PORT="$(jq -r '.services[] | select(.name=="falco") | .proxy_listen_port' config.json)"

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
  printf '%s' "Create falco namespace"
  NAMESPACE=${NAMESPACE} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# Falco
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

###
# Falco on Darwin
# 1. Install the driver on the host machine
# Clone the Falco project and checkout the tag corresponding to the same Falco version used within the helm chart (0.29.1 in my case), then:

# git checkout 0.29.1
# mkdir build
# cd build
# brew install yaml-cpp grpc
# export OPENSSL_ROOT_DIR=/usr/local/opt/openssl
# cmake ..
# sudo make install_driver
###
#######################################
# Deploys Falco to Kubernetes
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_falco() {
  ## deploy falco
  printf '%s\n' "deploy falco"

  helm repo add falcosecurity https://falcosecurity.github.io/charts
  helm repo update

  mkdir -p overrides
  envsubst <templates/falco-overrides.yaml >overrides/falco-overrides.yaml

  # If running on GKE or AKS we switch to eBPF
  if is_gke || is_aks || is_eks || is_kind ; then
    echo "ebpf:" >> overrides/falco-overrides.yaml
    echo "  enabled: true" >> overrides/falco-overrides.yaml
  fi

  echo "customRules:" > overrides/falco-custom-rules.yaml

  # If there is a file called `falco/playground_rules_dev.yaml`, we append it to the falco-custom-rules.yaml
  # and skip the playground and additional rule files
  if [ -f "falco/playground_rules_dev.yaml" ]; then
    printf '%s\n' "Playground Dev rules file found"
    echo "  a_playground_rules_dev.yaml: |-" >> overrides/falco-custom-rules.yaml
    cat falco/playground_rules_dev.yaml | sed  -e 's/^/    /' >> overrides/falco-custom-rules.yaml
  else    
    # If there is a file called `falco/playground_rules.yaml`, we append it to the falco-custom-rules.yaml
    if [ -f "falco/playground_rules.yaml" ]; then
      printf '%s\n' "Playground rules file found"
      echo "  a_playground_rules.yaml: |-" >> overrides/falco-custom-rules.yaml
      cat falco/playground_rules.yaml | sed  -e 's/^/    /' >> overrides/falco-custom-rules.yaml
    fi

    # If there is a file called `falco/additional_rules.yaml`, we append it to the falco-custom-rules.yaml
    if [ -f "falco/additional_rules.yaml" ]; then
      printf '%s\n' "Additional rules file found"
      echo "  z_additional_rules.yaml: |-" >> overrides/falco-custom-rules.yaml
      cat falco/additional_rules.yaml | sed  -e 's/^/    /' >> overrides/falco-custom-rules.yaml
    fi
  fi

  # helm delete falco && kubectl delete svc falco-np && rm /tmp/passthrough.conf && sleep 2 && ./deploy-falco.sh 

  # Install Falco
  helm -n ${NAMESPACE} upgrade \
    falco \
    --install \
    --values=overrides/falco-overrides.yaml \
    -f overrides/falco-custom-rules.yaml \
    falcosecurity/falco

  helm -n ${NAMESPACE} upgrade \
    falco-exporter \
    --install \
    falcosecurity/falco-exporter

  # Create NodePort Service to enable K8s Audit
  envsubst <templates/falco-nodeport-service.yaml | kubectl -n ${NAMESPACE} apply -f -
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
  printf '%s\n' "Create falco ingress"
  SERVICE_NAME=${SERVICE_NAME} \
    NAMESPACE=${NAMESPACE} \
    HOSTNAME=${HOSTNAME} \
    LISTEN_PORT=${LISTEN_PORT} \
    envsubst <templates/falco-ingress.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "Falco ingress created 🍻"
}

#######################################
# Main:
# Deploys Falco
#######################################
function main() {
  if is_darwin ; then
    echo "*** Falco currently not supported on MacOS ***"
    exit 0
  fi

  create_namespace
  whitelist_namsspace
  deploy_falco

  if is_linux ; then
    # test if we're using a kind cluster and need a proxy
    if is_kind ; then
      ./deploy-proxy.sh falco
      echo "Falco UI on: http://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}/ui/#/" | tee -a services
    fi
  fi
  if is_darwin ; then
    create_ingress
  fi
}

function cleanup() {
  helm -n ${NAMESPACE} delete \
    falco || true
  helm -n ${NAMESPACE} delete \
    falco-exporter || true
  kubectl delete namespace ${NAMESPACE} || true
  sudo rm -Rf log/*
  
  for i in {1..10} ; do
    sleep 2
    if [ "$(kubectl get all -n ${NAMESPACE} | grep 'No resources found' || true)" == "" ] ; then
      return
    fi
  done
  false
}

function test() {
  for i in {1..10} ; do
    sleep 5
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -n ${NAMESPACE} | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -n ${NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    PODS_TOTAL=$(kubectl get pods -n ${NAMESPACE} | wc -l)
    PODS_READY=$(kubectl get pods -n ${NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    if [[ ( $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ) && ( $((${PODS_TOTAL} - 1)) -eq ${PODS_READY} ) ]] ; then
      echo ${PODS_READY}
      if is_kind ; then
        for i in {1..10} ; do
          sleep 2
          if [ $(curl --write-out '%{http_code}' --silent --output /dev/null "http://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}/ui/#") -eq 200 ] ; then
            return
          fi
        done
      fi
      return
    fi
  done
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi