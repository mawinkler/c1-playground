#!/bin/bash

set -e

# Source helpers
. ./playground-helpers.sh

# Get config
NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' config.json)"
HOSTNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .hostname' config.json)"
SERVICE_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' config.json)"
SERVICE_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
STORAGE_SIZE="$(jq -r '.services[] | select(.name=="playground-registry") | .size' config.json)"
USERNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .username' config.json)"
PASSWORD="$(jq -r '.services[] | select(.name=="playground-registry") | .password' config.json)"

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
  printf '%s' "Create registry namespace"
  NAMESPACE=${NAMESPACE} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Creates Kubernetes service
# Globals:
#   NAMESPACE
#   SERVICE_NAME
#   SERVICE_TYPE
#   SERVICE_PORT
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_service() {
  printf '%s' "Create registry service"
  NAMESPACE=${NAMESPACE} \
    SERVICE_NAME=${SERVICE_NAME} \
    SERVICE_TYPE=${SERVICE_TYPE} \
    SERVICE_PORT=${SERVICE_PORT} \
    envsubst <templates/service.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Create authentication secret for
# registry
# Globals:
#   NAMESPACE
#   USERNAME
#   PASSWORD
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_auth_secret() {
  # create auth secret

  printf '%s' "Create registry auth secret"

  mkdir -p auth
  htpasswd -bBc auth/htpasswd ${USERNAME} ${PASSWORD}
  kubectl --namespace ${NAMESPACE} create secret generic auth-secret --from-file=auth/htpasswd -o yaml
  printf '%s\n' " 🍿"
}

#######################################
# Create server certificate
# Globals:
#   NAMESPACE
#   SERVICE_NAME
#   USERNAME
#   PASSWORD
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_tls_secret_linux() {
  printf '%s' "Create registry tls secret (linux)"
  EXTERNAL_IP=""
  while [[ "${EXTERNAL_IP}" == "" ]]; do
    sleep 1
    if is_eks ; then
      EXTERNAL_IP=$(kubectl --namespace ${NAMESPACE} get svc ${SERVICE_NAME} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      EXTERNAL_IP=$(dig +short ${EXTERNAL_IP} 2>&1 | head -n 1)
    else
      EXTERNAL_IP=$(kubectl --namespace ${NAMESPACE} get svc ${SERVICE_NAME} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi
    echo "External IP ${EXTERNAL_IP}"
  done

  mkdir -p certs
  EXTERNAL_IP=${EXTERNAL_IP} \
    EXTERNAL_IP_DASH=${EXTERNAL_IP//./-} \
    envsubst <templates/registry-server-tls-linux.conf >certs/req-reg.conf

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout certs/tls.key -out certs/tls.crt \
    -subj "/CN=${EXTERNAL_IP}" -extensions san -config certs/req-reg.conf
  kubectl --namespace ${NAMESPACE} create secret tls certs-secret --cert=certs/tls.crt --key=certs/tls.key -o yaml
  printf '%s\n' " 🍵"
}

#######################################
# Create server certificate
# Globals:
#   NAMESPACE
#   SERVICE_NAME
#   USERNAME
#   PASSWORD
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_tls_secret_darwin() {
  printf '%s' "create tls secret (darwin)"
  EXTERNAL_IP=""
  while [[ "${EXTERNAL_IP}" == "" ]]; do
    sleep 1
    EXTERNAL_IP=$(kubectl --namespace ${NAMESPACE} get svc ${SERVICE_NAME} \
                  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  done

  mkdir -p certs
  EXTERNAL_IP=${EXTERNAL_IP} \
    HOSTNAME=${HOSTNAME} \
    envsubst <templates/registry-server-tls-darwin.conf >certs/req-reg.conf

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout certs/tls.key -out certs/tls.crt \
    -subj "/CN=${EXTERNAL_IP}" -extensions san -config certs/req-reg.conf &> /dev/null
  kubectl --namespace ${NAMESPACE} create secret tls certs-secret --cert=certs/tls.crt --key=certs/tls.key -o yaml
  printf '%s\n' " 🍵"
}

#######################################
# Deploys Registry to Kubernetes
# Globals:
#   NAMESPACE
#   STORAGE_SIZE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_registry() {
  # create registry deployment

  printf '%s' "Create registry deployment"

  NAMESPACE=${NAMESPACE} \
    STORAGE_SIZE=${STORAGE_SIZE} \
    envsubst <templates/registry-volume-claim.yaml | kubectl apply -f - -o yaml
  NAMESPACE=${NAMESPACE} \
    SERVICE_NAME=${SERVICE_NAME} \
    SERVICE_PORT=${SERVICE_PORT} \
  envsubst <templates/registry-deployment.yaml | kubectl apply -f - -o yaml
  printf '%s\n' " 🍶"
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
  printf '%s\n' "Create registry ingress"
  NAMESPACE=${NAMESPACE} \
    SERVICE_NAME=${SERVICE_NAME} \
    SERVICE_PORT=${SERVICE_PORT} \
    HOSTNAME=${HOSTNAME} \
    envsubst <templates/registry-ingress.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "Registry ingress created 🍻"
}

if is_linux ; then
  SERVICE_TYPE='LoadBalancer'
  create_namespace
  create_service
  create_auth_secret
  create_tls_secret_linux
  deploy_registry
  echo "Registry login with: echo ${PASSWORD} | docker login https://${EXTERNAL_IP}:${SERVICE_PORT} --username ${USERNAME} --password-stdin" 
fi

if is_darwin ; then
  SERVICE_TYPE='LoadBalancer'
  create_namespace
  create_service
  create_auth_secret
  create_tls_secret_darwin
  deploy_registry
  create_ingress
  echo "Registry login with: echo ${PASSWORD} | docker login ${HOSTNAME}:443 --username ${USERNAME} --password-stdin" | tee -a services
fi
