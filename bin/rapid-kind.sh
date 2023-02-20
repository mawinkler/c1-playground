#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
CLUSTER_NAME="$(jq -r '.cluster_name' $PGPATH/config.json)"
HOST_IP=$(hostname -I | awk '{print $1}')

mkdir -p $PGPATH/overrides
mkdir -p ~/.docker
touch ~/.docker/config.json

#######################################
# Configure Docker network
# Globals:
#   CLUSTER_NAME
#   HOST_IP
#   HOST_REGISTRY_NAME
#   HOST_REGISTRY_PORT
# Arguments:
#   None
# Outputs:
#   None
#######################################
function configure_networking() {
  if [ "$(docker network list --filter name=kind --format "{{.Name}}")" == "kind" ] ; then
    printf '%s\n' "Reusing existing docker network"
  else
    printf '%s\n' "Creating docker network"
    docker network create \
      --driver=bridge \
      --subnet=172.250.0.0/16 \
      --ip-range=172.250.255.0/24 \
      --gateway=172.250.255.254 \
      kind
  fi
}

#######################################
# Creates a local Kubernetes cluster
# running on Linux
# Globals:
#   CLUSTER_NAME
#   HOST_IP
#   HOST_REGISTRY_NAME
#   HOST_REGISTRY_PORT
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_cluster_linux() {
  # Falco and Kubernetes Auditing
  # To enable Kubernetes audit logs, you need to change the arguments to the
  # kube-apiserver process to add --audit-policy-file and
  # --audit-webhook-config-file arguments and provide files that implement an
  # audit policy/webhook configuration.
  printf '%s\n' "Create K8s audit webhook (linux)"
  CLUSTER_NAME=${CLUSTER_NAME} \
    envsubst <$PGPATH/templates/kind-audit-webhook.yaml >$PGPATH/audit/audit-webhook.yaml

  printf '%s\n' "Create cluster (linux)"
  HOST_IP=${HOST_IP} \
    CLUSTER_NAME=${CLUSTER_NAME} \
    HOST_REGISTRY_NAME=${HOST_REGISTRY_NAME} \
    HOST_REGISTRY_PORT=${HOST_REGISTRY_PORT} \
    PLAYGROUND_HOME=$(pwd) \
    envsubst <$PGPATH/templates/kind-cluster-config-linux.yaml | kind create cluster --config=-
}

#######################################
# Creates a local Kubernetes cluster
# running on Darwin
# Globals:
#   CLUSTER_NAME
#   HOST_REGISTRY_NAME
#   HOST_REGISTRY_PORT
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_cluster_darwin() {
  printf '%s\n' "Create K8s audit webhook (darwin)"
  CLUSTER_NAME=${CLUSTER_NAME} \
    envsubst <$PGPATH/templates/kind-audit-webhook.yaml >$PGPATH/audit/audit-webhook.yaml

  printf '%s\n' "Create cluster (darwin)"
  CLUSTER_NAME=${CLUSTER_NAME} \
    HOST_REGISTRY_NAME=${HOST_REGISTRY_NAME} \
    HOST_REGISTRY_PORT=${HOST_REGISTRY_PORT} \
    PGPATH=${PGPATH} \
    envsubst <$PGPATH/templates/kind-cluster-config-darwin.yaml | kind create cluster --config=-
}

#######################################
# Creates a load balancer on the
# cluster
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_load_balancer() {
  printf '%s\n' "Create load balancer"
  # Link: https://metallb.universe.tf/installation/
  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
  # kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml -o yaml
  # kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml -o yaml

  kubectl create secret generic -n metallb-system memberlist \
    --from-literal=secretkey="$(openssl rand -base64 128)" -o yaml

  printf '%s' "Waiting for calico to be ready"
  for i in {1..600} ; do
    sleep 2
    DEPLOYMENTS_TOTAL=$(kubectl -n calico-apiserver get deployments 2> /dev/null | wc -l)
    DEPLOYMENTS_READY=$(kubectl -n calico-apiserver get deployments 2> /dev/null | grep -E "([0-9]+)/\1" | wc -l)
    if [[ $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ]] ; then
      break
    fi
    printf '%s' "."
  done
  printf '\n'

  printf '%s' "Waiting for metallb to be ready"
  for i in {1..600} ; do
    sleep 2
    ADDRESS_POOL=$(kubectl get nodes -o json | \
      jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address' | \
      sed -r 's|([0-9]*).([0-9]*).*|\1.\2.255.1-\1.\2.255.250|' 2> /dev/null)
    if [ "${ADDRESS_POOL}" != "" ] ; then
      break
    fi
    printf '%s' "."
  done    
  printf '\n'
  printf '%s\n' "Load balancer address pool ${ADDRESS_POOL}"
  ADDRESS_POOL=${ADDRESS_POOL} \
    envsubst <$PGPATH/templates/kind-load-balancer-addresspool.yaml | kubectl apply -f - -o yaml
  echo kind-load-balancer-addresspool.yaml
  envsubst <$PGPATH/templates/kind-load-balancer-l2adv.yaml | kubectl apply -f - -o yaml

  printf '%s\n' "Load balancer created 🍹"
}

#######################################
# Creates an ingress controller
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_ingress_controller() {
  # ingress nginx
  printf '%s\n' "Create ingress controller"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml -o yaml

  printf '%s' "Waiting for the cluster to be ready"
  for i in {1..60} ; do
    sleep 2
    DEPLOYMENTS_TOTAL=$(kubectl -n kube-system get deployments | wc -l)
    DEPLOYMENTS_READY=$(kubectl -n kube-system get deployments | grep -E "([0-9]+)/\1" | wc -l)
    if [[ $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ]] ; then
      break
    fi
    printf '%s' "."
  done
  printf '\n'

  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s \
    -o yaml
  printf '\n%s\n' "Ingress controller ready 🍾"
}

#######################################
# Deploys Calico pod network
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_calico() {
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
}

#######################################
# Main:
# Creates a Kind based Kubernetes
# cluster on linux and darwin operating
# systems
#######################################
function main() {
  # flush services
  echo > $PGPATH/services

  # If playing with proxied connections
  # export HTTP_PROXY=172.17.0.1:3128
  # export HTTPS_PROXY=172.17.0.1:3128
  # export NO_PROXY=localhost,127.0.0.1

  configure_networking
  if is_linux ; then
    create_cluster_linux
    deploy_calico
    create_load_balancer
    create_ingress_controller
    $PGPATH/bin/deploy-registry.sh
    printf '\n%s\n' "Cluster ready 🍾"
  fi

  if is_darwin ; then
    create_cluster_darwin
    deploy_calico
    create_load_balancer
    create_ingress_controller
    $PGPATH/bin/deploy-registry.sh
    printf '\n%s\n' "Cluster ready 🍾"
  fi
}

function cleanup() {
  ./down.sh
  if [ "$(docker ps -q --filter name=${CLUSTER_NAME})" == "" ] ; then
    return
  fi
  false
}

function test() {
  DEPLOYMENTS_TOTAL=$(kubectl get deployments -A | wc -l)
  DEPLOYMENTS_READY=$(kubectl get deployments -A | grep -E "([0-9]+)/\1" | wc -l)
  if [ $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ] ; then
    echo ${DEPLOYMENTS_READY}
    return
  fi
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi
