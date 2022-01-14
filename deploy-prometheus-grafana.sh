#!/bin/bash

set -e

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
PROMETHEUS_HOSTNAME="$(jq -r '.services[] | select(.name=="prometheus") | .hostname' config.json)"
PROMETHEUS_LISTEN_PORT="$(jq -r '.services[] | select(.name=="prometheus") | .proxy_listen_port' config.json)"
GRAFANA_HOSTNAME="$(jq -r '.services[] | select(.name=="grafana") | .hostname' config.json)"
GRAFANA_LISTEN_PORT="$(jq -r '.services[] | select(.name=="grafana") | .proxy_listen_port' config.json)"
GRAFANA_PASSWORD="$(jq -r '.services[] | select(.name=="grafana") | .password' config.json)"
NAMESPACE="$(jq -r '.services[] | select(.name=="prometheus") | .namespace' config.json)"
HOMEASSISTANT_API_KEY="$(jq -r '.services[] | select(.name=="hass") | .api_key' config.json)"
OS="$(uname)"

if [[ $(kubectl config current-context) =~ gke_.*|aks-.*|.*eksctl.io ]]; then
  echo Running on GKE, AKS or EKS
fi

function create_prometheus_namespace {
  printf '%s' "Create Prometheus namespace"

  # create service
  cat <<EOF | kubectl apply -f - -o yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namespaces {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespaces
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=true
}

# helm show values prometheus-community/kube-prometheus-stack
function deploy_prometheus {
  ## deploy prometheus
  printf '%s\n' "deploy prometheus"

  mkdir -p overrides
  cat <<EOF >overrides/overrides-prometheus.yml
grafana:
  enabled: true
  adminPassword: ${GRAFANA_PASSWORD}
  service:
    type: ${SERVICE_TYPE}
prometheusOperator:
  enabled: true
  service:
    type: ${SERVICE_TYPE}
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
    type: ${SERVICE_TYPE}
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

function create_ingress {
    # create ingress for prometheus and grafana

  printf '%s\n' "Create prometheus and grafana ingress"
  cat <<EOF | kubectl apply -f - -o yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: HTTP
  name: prometheus-grafana
  namespace: ${NAMESPACE}
spec:
  # tls:
  # - hosts:
  #   - ${PROMETHEUS_HOSTNAME}
  #   - ${GRAFANA_HOSTNAME}
  rules:
    - host: ${PROMETHEUS_HOSTNAME}
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: prometheus-kube-prometheus-prometheus
              port:
                number: 9090
    - host: ${GRAFANA_HOSTNAME}
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: prometheus-grafana
              port:
                number: 80                
EOF
  printf '%s\n' "Prometheus and grafana ingress created 🍻"
}


create_prometheus_namespace
whitelist_namespaces

if [ "${OS}" == 'Linux' ]; then
  SERVICE_TYPE='LoadBalancer'
  deploy_prometheus
  # test if we're using a managed kubernetes cluster on GCP, Azure (or AWS)
  if [[ ! $(kubectl config current-context) =~ gke_.*|aks-.*|.*eksctl.io ]]; then
    ./deploy-proxy.sh prometheus
    ./deploy-proxy.sh grafana
    HOST_IP=$(hostname -I | awk '{print $1}')
    echo "Prometheus UI on: http://${HOST_IP}:${PROMETHEUS_LISTEN_PORT}" >> services
    echo "Grafana UI on: http://${HOST_IP}:${GRAFANA_LISTEN_PORT} w/ admin/${GRAFANA_PASSWORD}" >> services
  fi
fi

if [ "${OS}" == 'Darwin' ]; then
  SERVICE_TYPE='ClusterIP'
  deploy_prometheus
  create_ingress
  echo "Prometheus UI on: http://${PROMETHEUS_HOSTNAME}" >> services
  echo "Grafana UI on: http://${GRAFANA_HOSTNAME} w/ admin/${GRAFANA_PASSWORD}" >> services
fi
