#!/bin/bash

set -e

# Source helpers
. ./playground-helpers.sh

# Get config
CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
PROMETHEUS_HOSTNAME="$(jq -r '.services[] | select(.name=="prometheus") | .hostname' config.json)"
PROMETHEUS_LISTEN_PORT="$(jq -r '.services[] | select(.name=="prometheus") | .proxy_listen_port' config.json)"
GRAFANA_HOSTNAME="$(jq -r '.services[] | select(.name=="grafana") | .hostname' config.json)"
GRAFANA_LISTEN_PORT="$(jq -r '.services[] | select(.name=="grafana") | .proxy_listen_port' config.json)"
GRAFANA_PASSWORD="$(jq -r '.services[] | select(.name=="grafana") | .password' config.json)"
NAMESPACE="$(jq -r '.services[] | select(.name=="prometheus") | .namespace' config.json)"
HOMEASSISTANT_API_KEY="$(jq -r '.services[] | select(.name=="hass") | .api_key' config.json)"

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
  printf '%s' "Create prometheus namespace"
  NAMESPACE=${NAMESPACE} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# Prometheus
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function whitelist_namespace() {
  printf '%s\n' "whitelist namespaces"
  # whitelist some namespaces
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=true
}

# helm show values prometheus-community/kube-prometheus-stack
#######################################
# Deploys Prometheus and Grafana to
# Kubernetes
# Globals:
#   GRAFANA_PASSWORD
#   SERVICE_TYPE
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_prometheus() {
  ## deploy prometheus
  printf '%s\n' "deploy prometheus"

  mkdir -p overrides
  GRAFANA_PASSWORD=${GRAFANA_PASSWORD} \
    SERVICE_TYPE=${SERVICE_TYPE} \
    envsubst <templates/prometheus-overrides.yaml >overrides/prometheus-overrides.yaml

  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add stable https://charts.helm.sh/stable
  helm repo update

  helm upgrade \
    prometheus \
    --values overrides/prometheus-overrides.yaml \
    --namespace ${NAMESPACE} \
    --install \
    prometheus-community/kube-prometheus-stack
}

#######################################
# Creates Kubernetes ingress
# Globals:
#   NAMESPACE
#   PROMETHEUS_HOSTNAME
#   GRAFANA_HOSTNAME
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_ingress() {
  printf '%s\n' "Create prometheus and grafana ingress"
  NAMESPACE=${NAMESPACE} \
    PROMETHEUS_HOSTNAME=${PROMETHEUS_HOSTNAME} \
    GRAFANA_HOSTNAME=${GRAFANA_HOSTNAME} \
    envsubst <templates/prometheus-ingress.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "Prometheus and grafana ingress created 🍻"
}


create_namespace
whitelist_namespace

if is_linux; then
  SERVICE_TYPE='LoadBalancer'
  deploy_prometheus
  # test if we're using a managed kubernetes cluster on GCP, Azure (or AWS)
  if [[ ! $(kubectl config current-context) =~ gke_.*|aks-.*|.*eksctl.io ]]; then
    ./deploy-proxy.sh prometheus
    ./deploy-proxy.sh grafana
    HOST_IP=$(hostname -I | awk '{print $1}')
    echo "Prometheus UI on: http://${HOST_IP}:${PROMETHEUS_LISTEN_PORT}" | tee -a services
    echo "Grafana UI on: http://${HOST_IP}:${GRAFANA_LISTEN_PORT} w/ admin/${GRAFANA_PASSWORD}" | tee -a services
  fi
fi
if is_darwin; then
  SERVICE_TYPE='ClusterIP'
  deploy_prometheus
  create_ingress
  echo "Prometheus UI on: http://${PROMETHEUS_HOSTNAME}" | tee -a services
  echo "Grafana UI on: http://${GRAFANA_HOSTNAME} w/ admin/${GRAFANA_PASSWORD}" | tee -a services
fi
