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

function create_grafana_namespace {
  printf '%s' "Create Grafana namespace"

  echo "---" >>up.log
  # create service
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: grafana
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspaces {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespaces
  kubectl label namespace prometheus --overwrite ignoreAdmissionControl=ignore
  kubectl label namespace grafana --overwrite ignoreAdmissionControl=ignore
}

# helm show values prometheus-community/kube-prometheus-stack
function deploy_prometheus {
  ## deploy prometheus
  printf '%s\n' "deploy prometheus"

  mkdir -p overrides
  cat <<EOF >overrides/overrides-prometheus.yml
grafana:
  enabled: true
  adminPassword: prom-operator
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
      scrape_interval: 10s
      metrics_path: /metrics
      static_configs:
      - targets: ['api-collector:8000']
EOF

# server:
#   persistentVolume:
#     enabled: true
#   service:
#     type: LoadBalancer
#   retention: "15d"

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

function deploy_grafana {
  ## deploy grafana
  printf '%s\n' "deploy grafana"

  SERVICE_HOST=''
  SERVICE_PORT=0
  while [ "$SERVICE_HOST" == '' ]
  do
    SERVICE_HOST=$(kubectl get svc -n prometheus prometheus-kube-prometheus-prometheus \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    SERVICE_PORT=$(kubectl get svc -n prometheus prometheus-kube-prometheus-prometheus \
                -o jsonpath='{.spec.ports[0].port}')
    sleep 2
  done

  cat <<EOF >overrides/overrides-grafana.yml
service:
  type: LoadBalancer
persistence:
  enabled: true
adminUser: admin
adminPassword: trendmicro
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://${SERVICE_HOST}:${SERVICE_PORT}
      access: proxy
      isDefault: true
EOF

  helm repo add stable https://charts.helm.sh/stable
  helm repo update

  helm upgrade \
    grafana \
    --values overrides/overrides-grafana.yml \
    --namespace grafana \
    --install \
    stable/grafana
}

create_prometheus_namespace
# create_grafana_namespace
whitelist_namsspaces
deploy_prometheus
# deploy_grafana

