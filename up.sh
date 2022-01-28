#!/bin/bash
set -o errexit

# Source helpers
. ./playground-helpers.sh

# Get config
CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
HOST_IP=$(hostname -I | awk '{print $1}')

mkdir -p overrides

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
  if [ $(docker network list --filter name=kind --format "{{.Name}}") == "kind" ] ; then
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
    envsubst <templates/kind-audit-webhook.yaml >audit/audit-webhook.yaml

  printf '%s\n' "Create cluster (linux)"
  HOST_IP=${HOST_IP} \
    CLUSTER_NAME=${CLUSTER_NAME} \
    HOST_REGISTRY_NAME=${HOST_REGISTRY_NAME} \
    HOST_REGISTRY_PORT=${HOST_REGISTRY_PORT} \
    PLAYGROUND_HOME=$(pwd) \
    envsubst <templates/kind-cluster-config-linux.yaml | kind create cluster --config=-
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
    envsubst <templates/kind-audit-webhook.yaml >audit/audit-webhook.yaml

  printf '%s\n' "Create cluster (darwin)"
  CLUSTER_NAME=${CLUSTER_NAME} \
    HOST_REGISTRY_NAME=${HOST_REGISTRY_NAME} \
    HOST_REGISTRY_PORT=${HOST_REGISTRY_PORT} \
    PLAYGROUND_HOME=$(pwd) \
    envsubst <templates/kind-cluster-config-darwin.yaml | kind create cluster --config=-
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
   kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml -o yaml
   kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml -o yaml
   kubectl create secret generic -n metallb-system memberlist \
    --from-literal=secretkey="$(openssl rand -base64 128)" -o yaml
  ADDRESS_POOL=$(kubectl get nodes -o json | \
    jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address' | \
    sed -r 's|([0-9]*).([0-9]*).*|\1.\2.255.1-\1.\2.255.250|')
  ADDRESS_POOL=${ADDRESS_POOL} \
    envsubst <templates/kind-load-balancer-config.yaml | kubectl apply -f - -o yaml
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
  # wating for the cluster be ready
  printf '%s' "Wating for the cluster be ready"
  while [ $(kubectl -n kube-system get deployments | \
          grep -cE "1/1|2/2|3/3|4/4|5/5") -ne $(kubectl -n kube-system get deployments | \
          grep -c "/") ]; do
    printf '%s' "."
    sleep 2
  done
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s \
    -o yaml
  printf '\n%s\n' "Ingress controller ready 🍾"
}

#######################################
# Deploys CAdvisor
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_cadvisor() {
  kubectl apply -f https://raw.githubusercontent.com/astefanutti/kubebox/master/cadvisor.yaml
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
  kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
  # By default, Calico pods fail if the Kernel's Reverse Path Filtering (RPF) check
  # is not enforced. This is a security measure to prevent endpoints from spoofing
  # their IP address.
  # The RPF check is not enforced in Kind nodes. Thus, we need to disable the
  # Calico check by setting an environment variable in the calico-node DaemonSet
  kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
}

#######################################
# Main:
# Creates a Kind based Kubernetes
# cluster on linux and darwin operating
# systems
#######################################
function main() {
  # flush services
  echo > services

  configure_networking
  if is_linux ; then
    create_cluster_linux
    deploy_cadvisor
    deploy_calico
    create_load_balancer
    create_ingress_controller
    printf '\n%s\n' "Cluster ready 🍾"
  fi

  if is_darwin ; then
    create_cluster_darwin
    deploy_cadvisor
    deploy_calico
    create_load_balancer
    create_ingress_controller
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
