#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
NAMESPACE="$(jq -r '.services[] | select(.name=="harbor") | .namespace' $PGPATH/config.json)"
COMMON_NAME="$(jq -r '.services[] | select(.name=="harbor") | .common_name' $PGPATH/config.json)"
SERVICE_NAME="$(jq -r '.services[] | select(.name=="harbor") | .proxy_service_name' $PGPATH/config.json)"
LISTEN_PORT="$(jq -r '.services[] | select(.name=="harbor") | .proxy_service_port' $PGPATH/config.json)"
PROXY_LISTEN_PORT="$(jq -r '.services[] | select(.name=="harbor") | .proxy_listen_port' $PGPATH/config.json)"
ADMIN_PASSWORD="$(jq -r '.services[] | select(.name=="harbor") | .admin_password' $PGPATH/config.json)"
REG_USERNAME="$(jq -r '.services[] | select(.name=="harbor") | .reg_username' $PGPATH/config.json)"
REG_PASSWORD="$(jq -r '.services[] | select(.name=="harbor") | .reg_password' $PGPATH/config.json)"
REG_HTPASSWD="$(jq -r '.services[] | select(.name=="harbor") | .reg_htpasswd' $PGPATH/config.json)"
# SC_REG_HOSTNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_hostname' $PGPATH/config.json)"

SERVICE_TYPE=loadBalancer
HARBOR_URL=https://${COMMON_NAME}

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
  printf '%s' "Create harbor namespace"
  NAMESPACE=${NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# Harbor
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

#######################################
# Creates SSL certificate for linux
# playgrounds
# Globals:
#   SC_HOST
#   SC_NAMESPACE
# Arguments:
#   None
# Outputs:
#   certs/sc.crt
#   certs/sc.key
#######################################
function create_ssl_certificate_linux() {
  # create ssl certificate
  printf '%s' "Create ssl certificate (linux)"
  mkdir -p $PGPATH/certs
  cat <<EOF >$PGPATH/certs/req-sc.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:${COMMON_NAME//./-}.nip.io,IP:${COMMON_NAME}
EOF

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout $PGPATH/certs/sc.key -out $PGPATH/certs/sc.crt \
    -subj "/CN=${COMMON_NAME//./-}.nip.io" -extensions san -config $PGPATH/certs/req-sc.conf
  kubectl create secret tls k8s-certificate --cert=$PGPATH/certs/sc.crt --key=$PGPATH/certs/sc.key \
    --dry-run=true -n ${NAMESPACE} -o yaml | kubectl apply -f - -o yaml
  printf '%s\n' " 🍵"
}

#######################################
# Deploys Harbor to Kubernetes
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_harbor() {
  ## deploy harbor
  printf '%s\n' "deploy harbor"

  helm repo add harbor https://helm.goharbor.io
  helm repo update

  mkdir -p $PGPATH/overrides
  SERVICE_TYPE=${SERVICE_TYPE} \
    COMMON_NAME=${COMMON_NAME} \
    LISTEN_PORT=${LISTEN_PORT} \
    HARBOR_URL=${HARBOR_URL} \
    ADMIN_PASSWORD=${ADMIN_PASSWORD} \
    REG_USERNAME=${REG_USERNAME} \
    REG_PASSWORD=${REG_PASSWORD} \
    REG_HTPASSWD=${REG_HTPASSWD} \
    envsubst <$PGPATH/templates/harbor-overrides.yaml >$PGPATH/overrides/harbor-overrides.yaml

  # Install harbor
  helm -n ${NAMESPACE} upgrade \
    harbor \
    --install \
    --values=$PGPATH/overrides/harbor-overrides.yaml \
    harbor/harbor
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
  printf '%s\n' "Create harbor ingress"
  SERVICE_NAME=${SERVICE_NAME} \
    NAMESPACE=${NAMESPACE} \
    HOSTNAME=${HOSTNAME} \
    LISTEN_PORT=${LISTEN_PORT} \
    envsubst <$PGPATH/templates/harbor-ingress.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "Harbor ingress created 🍻"
}

#######################################
# Main:
# Deploys harbor
#######################################
function main() {
  echo "*** Harbor deployment currently in BETA ***"

  if is_darwin ; then
    echo "*** Harbor currently not supported on MacOS ***"
    exit 0
  fi

  create_namespace
  whitelist_namsspace
  create_ssl_certificate_linux
  deploy_harbor

  if is_linux ; then
    # test if we're using a kind cluster and need a proxy
    if is_kind ; then
      $PGPATH/bin/deploy-proxy.sh harbor
      echo "Harbor: https://$(hostname -I | awk '{print $1}'):${PROXY_LISTEN_PORT}" | tee -a $PGPATH/services
      echo "  U/P: admin / ${ADMIN_PASSWORD}" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
    fi
  fi
  if is_darwin ; then
    create_ingress
  fi
}

function cleanup() {
  helm -n ${NAMESPACE} delete \
    harbor || true
  kubectl delete namespace ${NAMESPACE} || true
  
  for i in {1..10} ; do
    sleep 2
    if [ "$(kubectl get all -n ${NAMESPACE} | grep 'No resources found' || true)" == "" ] ; then
      return
    fi
  done
  false
}

function get_ui() {
  if is_kind ; then
    if is_linux ; then
      UI_URL="http://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}"
    else
      echo "*** harbor currently not supported on MacOS ***"
    fi
  else
    if is_eks ; then
      UI_URL="http://$(kubectl -n ${NAMESPACE} get svc harbor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):${LISTEN_PORT}"
    else
      UI_URL="http://$(kubectl -n ${NAMESPACE} get svc harbor -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):${LISTEN_PORT}"
    fi
  fi
}

function test() {
  for i in {1..20} ; do
    sleep 5
    # test deployments and pods
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -n ${NAMESPACE} | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -n ${NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    PODS_TOTAL=$(kubectl get pods -n ${NAMESPACE} | wc -l)
    PODS_READY=$(kubectl get pods -n ${NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    if [[ ( $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ) && ( $((${PODS_TOTAL} - 1)) -eq ${PODS_READY} ) ]] ; then
      echo ${DEPLOYMENTS_READY}
      # test web app
      get_ui
      echo ${UI_URL}
      for i in {1..10} ; do
        sleep 2
        if [ $(curl --write-out '%{http_code}' --silent --output /dev/null ${UI_URL} -eq 200) ] ; then
          return
        fi
      done
      return
    fi
  done
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi