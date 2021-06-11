#!/bin/bash

set -e

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
NAMESPACE="$(jq -r '.services[] | select(.name=="prometheus") | .namespace' config.json)"
HOMEASSISTANT_API_KEY="$(jq -r '.services[] | select(.name=="hass") | .api_key' config.json)"
OS="$(uname)"

function create_prometheus_namespace {
  printf '%s' "Create Prometheus namespace"

  echo "---" >>up.log
  # create service
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspaces {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespaces
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=ignore
  kubectl label namespace ${NAMESPACE} --overwrite network=green
}

# helm show values prometheus-community/kube-prometheus-stack
function deploy_prometheus {
  ## deploy prometheus
  printf '%s\n' "deploy prometheus"

  mkdir -p overrides
  cat <<EOF >overrides/overrides-prometheus.yml
grafana:
  enabled: true
  adminPassword: operator
  service:
    type: LoadBalancer
prometheusOperator:
  enabled: true
  service:
    type: LoadBalancer
  namespaces:
    releaseNamespace: true
    additional:
    - kube-system
    - smartcheck
    - container-security
    - registry
    - falco
prometheus:
  enabled: true
  service:
    type: LoadBalancer
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: api-collector
      scrape_interval: 60s
      scrape_timeout: 30s
      scheme: http
      metrics_path: /
      static_configs:
      - targets: ['api-collector:8000']
    - job_name: falco
      scrape_interval: 15s
      scrape_timeout: 5s
      scheme: http
      metrics_path: /metrics
      static_configs:
      - targets: ['falco-exporter.falco:9376']
    - job_name: smartcheck-metrics
      scrape_interval: 15s
      scrape_timeout: 5s
      scheme: http
      metrics_path: /metrics
      static_configs:
      - targets: ['metrics.smartcheck:8082']
EOF

  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add stable https://charts.helm.sh/stable
  helm repo update

  helm upgrade \
    prometheus \
    --values overrides/overrides-prometheus.yml \
    --namespace ${NAMESPACE} \
    --install \
    prometheus-community/kube-prometheus-stack
}

create_prometheus_namespace
whitelist_namsspaces
deploy_prometheus

if [ "${OS}" == 'Linux' ]; then
  ./deploy-proxy.sh prometheus
  ./deploy-proxy.sh grafana
fi
