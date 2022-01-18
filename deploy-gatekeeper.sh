#!/bin/bash

set -e

# Source helpers
. ./playground-helpers.sh

# Get config
NAMESPACE="$(jq -r '.services[] | select(.name=="gatekeeper") | .namespace' config.json)"

mkdir -p gatekeeper

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
  printf '%s' "Create gatekeeper namespace"
  NAMESPACE=${NAMESPACE} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# Falco
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
# Create a CA and a server certificate
# for the Gatekeeper webhook receiver
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_tls_secret() {
  printf '%s' "Create gatekeeper webhook server tls secret"
  envsubst <templates/gatekeeper-server-tls.conf >gatekeeper/webhook-server-tls.conf

  openssl genrsa -out gatekeeper/admission-ca.key 2048
  openssl req -x509 -new -nodes -key gatekeeper/admission-ca.key -days 100000 -out gatekeeper/admission-ca.crt -subj "/CN=admission_ca"

  openssl genrsa -out gatekeeper/webhook-server-tls.key 2048
  openssl req -new -key gatekeeper/webhook-server-tls.key -out gatekeeper/webhook-server-tls.csr -config gatekeeper/webhook-server-tls.conf
  openssl x509 -req -in gatekeeper/webhook-server-tls.csr -CA gatekeeper/admission-ca.crt -CAkey gatekeeper/admission-ca.key -CAcreateserial -out gatekeeper/webhook-server-tls.crt -days 100000 -extensions v3_req -extfile gatekeeper/webhook-server-tls.conf

  kubectl -n ${NAMESPACE} create secret tls gatekeeper-server --cert=gatekeeper/webhook-server-tls.crt --key=gatekeeper/webhook-server-tls.key
  printf '%s\n' " 🍵"
}

#######################################
# Deploys Gatekeeper to Kubernetes
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_gatekeeper() {
  printf '%s\n' "deploy gatekeeper"
  envsubst <templates/gatekeeper-overrides.yaml >overrides/gatekeeper-overrides.yaml

  helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
  helm upgrade \
    gatekeeper \
    --values overrides/gatekeeper-overrides.yaml \
    --namespace ${NAMESPACE} \
    --install \
    gatekeeper/gatekeeper
}

create_namespace
whitelist_namsspace
# create_tls_secret
deploy_gatekeeper
