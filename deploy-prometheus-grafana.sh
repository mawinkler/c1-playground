#!/bin/bash

set -e

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"

function create_prometheus_namespace {
  printf '%s' "Create Prometheus namespace"

  echo "---" >>up.log
  # create service
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: prometheus
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspaces {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespaces
  kubectl label namespace prometheus --overwrite ignoreAdmissionControl=ignore
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
prometheus:
  enabled: true
  service:
    type: LoadBalancer
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: api-collector
      scrape_interval: 60s
      metrics_path: /
      static_configs:
      - targets: ['api-collector:8000']
EOF

  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add stable https://charts.helm.sh/stable
  helm repo update

  helm upgrade \
    prometheus \
    --values overrides/overrides-prometheus.yml \
    --namespace prometheus \
    --install \
    prometheus-community/kube-prometheus-stack
}

create_prometheus_namespace
whitelist_namsspaces
deploy_prometheus
