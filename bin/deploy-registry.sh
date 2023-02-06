#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' $PGPATH/config.json)"
HOSTNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .hostname' $PGPATH/config.json)"
SERVICE_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' $PGPATH/config.json)"
SERVICE_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' $PGPATH/config.json)"
STORAGE_SIZE="$(jq -r '.services[] | select(.name=="playground-registry") | .size' $PGPATH/config.json)"
LISTEN_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .proxy_listen_port' $PGPATH/config.json)"
USERNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .username' $PGPATH/config.json)"
PASSWORD="$(jq -r '.services[] | select(.name=="playground-registry") | .password' $PGPATH/config.json)"

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
  NAMESPACE=${NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
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
    envsubst <$PGPATH/templates/service.yaml | kubectl apply -f - -o yaml > /dev/null
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
  printf '%s' "Create registry auth secret"

  mkdir -p $PGPATH/auth
  htpasswd -bBc $PGPATH/auth/htpasswd ${USERNAME} ${PASSWORD}
  kubectl --ignore-not-found=true --namespace ${NAMESPACE} delete secret auth-secret
  kubectl --namespace ${NAMESPACE} create secret generic auth-secret --from-file=$PGPATH/auth/htpasswd -o yaml
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
      LB_IP=${EXTERNAL_IP}
    else
      LB_IP=$(kubectl --namespace ${NAMESPACE} get svc ${SERVICE_NAME} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      EXTERNAL_IP=$(hostname -I | awk '{print $1}')
    fi
    echo "External IP ${EXTERNAL_IP}"
  done

  mkdir -p $PGPATH/certs
  LB_IP=${LB_IP} \
    EXTERNAL_IP=${EXTERNAL_IP} \
    EXTERNAL_IP_DASH=${EXTERNAL_IP//./-} \
    envsubst <$PGPATH/templates/registry-server-tls-linux.conf >$PGPATH/certs/req-reg.conf

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout $PGPATH/certs/tls.key -out $PGPATH/certs/tls.crt \
    -subj "/CN=${EXTERNAL_IP}" -extensions san -config $PGPATH/certs/req-reg.conf
  kubectl --ignore-not-found=true --namespace ${NAMESPACE} delete secret certs-secret
  kubectl --namespace ${NAMESPACE} create secret tls certs-secret --cert=$PGPATH/certs/tls.crt --key=$PGPATH/certs/tls.key -o yaml
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

  mkdir -p $PGPATH/certs
  EXTERNAL_IP=${EXTERNAL_IP} \
    HOSTNAME=${HOSTNAME} \
    envsubst <$PGPATH/templates/registry-server-tls-darwin.conf >$PGPATH/certs/req-reg.conf

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout $PGPATH/certs/tls.key -out $PGPATH/certs/tls.crt \
    -subj "/CN=${EXTERNAL_IP}" -extensions san -config $PGPATH/certs/req-reg.conf &> /dev/null
  kubectl --ignore-not-found=true --namespace ${NAMESPACE} delete secret certs-secret
  kubectl --namespace ${NAMESPACE} create secret tls certs-secret --cert=$PGPATH/certs/tls.crt --key=$PGPATH/certs/tls.key -o yaml
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
    envsubst <$PGPATH/templates/registry-volume-claim.yaml | kubectl apply -f - -o yaml
  NAMESPACE=${NAMESPACE} \
    SERVICE_NAME=${SERVICE_NAME} \
    SERVICE_PORT=${SERVICE_PORT} \
  envsubst <$PGPATH/templates/registry-deployment.yaml | kubectl apply -f - -o yaml
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
    envsubst <$PGPATH/templates/registry-ingress.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "Registry ingress created 🍻"
}

function main() {
  if is_linux ; then
    SERVICE_TYPE='LoadBalancer'
    create_namespace
    create_service
    create_auth_secret
    create_tls_secret_linux
    deploy_registry
    if is_gke || is_aks || is_eks ; then
      echo "Registry: https://${EXTERNAL_IP}:${SERVICE_PORT}" | tee -a $PGPATH/services
      echo "  U/P: ${USERNAME} / ${PASSWORD}" | tee -a $PGPATH/services
      echo "  $ echo ${PASSWORD} | \\" | tee -a $PGPATH/services
      echo "      docker login https://${EXTERNAL_IP}:${SERVICE_PORT} --username ${USERNAME} --password-stdin" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
    else
      $PGPATH/bin/deploy-proxy.sh playground-registry
      # echo "Registry login with: echo ${SC_REG_PASSWORD} | docker login https://$(hostname) -I | awk '{print $1}'):5000 --username ${SC_REG_USERNAME} --password-stdin" | tee -a services
      echo "Registry: https://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}" | tee -a $PGPATH/services
      echo "  U/P: ${USERNAME} / ${PASSWORD}" | tee -a $PGPATH/services
      echo "  $ echo ${PASSWORD} | \\" | tee -a $PGPATH/services
      echo "      docker login https://$(hostname -I | awk '{print $1}'):${LISTEN_PORT} --username ${USERNAME} --password-stdin" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
    fi

  fi

  if is_darwin ; then
    SERVICE_TYPE='LoadBalancer'
    create_namespace
    create_service
    create_auth_secret
    create_tls_secret_darwin
    deploy_registry
    create_ingress
    echo "Registry login with: echo ${PASSWORD} | docker login ${HOSTNAME}:443 --username ${USERNAME} --password-stdin" | tee -a $PGPATH/services
    kubectl -n ${NAMESPACE} get svc -o=jsonpath='{.items[].metadata.name}' &> /dev/null
  fi
}

function cleanup() {
  rm -f \
    $PGPATH/certs/req-reg.conf \
    $PGPATH/certs/tls.crt \
    $PGPATH/certs/tls.key
  kubectl delete namespace ${NAMESPACE} || true
  ! kubectl -n ${NAMESPACE} get svc -o=jsonpath='{.items[].metadata.name}'
}

function test() {
  get_registry
  echo ${PASSWORD} | docker login https://${REGISTRY} --username ${USERNAME} --password-stdin
  IMAGE=busybox:latest
  docker pull ${IMAGE}
  docker tag ${IMAGE} ${REGISTRY}/${IMAGE}
  docker push ${REGISTRY}/${IMAGE}
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi