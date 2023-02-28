#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
NAMESPACE="$(jq -r '.services[] | select(.name=="opa") | .namespace' $PGPATH/config.json)"

mkdir -p $PGPATH/opa

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
  NAMESPACE=${NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# OPA
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function whitelist_namsspace() {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespaces
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=true
  kubectl label namespace ${NAMESPACE} --overwrite openpolicyagent.org/webhook=ignore
  kubectl label namespace kube-system  --overwrite openpolicyagent.org/webhook=ignore
}

#######################################
# Create a CA and a server certificate
# for the OPA webhook receiver
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_tls_secret {
  # create tls secret
  printf '%s' "Create opa webhook server tls secret"
  envsubst <$PGPATH/templates/opa-server-tls.conf >$PGPATH/opa/webhook-server-tls.conf

  openssl genrsa -out $PGPATH/opa/admission-ca.key 2048
  openssl req -x509 -new -nodes -key $PGPATH/opa/admission-ca.key -days 100000 -out $PGPATH/opa/admission-ca.crt -subj "/CN=admission_ca"

  openssl genrsa -out $PGPATH/opa/webhook-server-tls.key 2048
  openssl req -new -key $PGPATH/opa/webhook-server-tls.key -out $PGPATH/opa/webhook-server-tls.csr -config $PGPATH/opa/webhook-server-tls.conf
  openssl x509 -req -in $PGPATH/opa/webhook-server-tls.csr -CA $PGPATH/opa/admission-ca.crt -CAkey $PGPATH/opa/admission-ca.key -CAcreateserial -out $PGPATH/opa/webhook-server-tls.crt -days 100000 -extensions v3_req -extfile $PGPATH/opa/webhook-server-tls.conf

  kubectl -n opa create secret tls opa-server --cert=$PGPATH/opa/webhook-server-tls.crt --key=$PGPATH/opa/webhook-server-tls.key
  printf '%s\n' " 🍵"
}

#######################################
# Deploys OPA to Kubernetes
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_opa() {
  ## deploy opa
  printf '%s\n' "deploy opa"
  envsubst <$PGPATH/templates/opa-admission-controller.yaml >$PGPATH/opa/admission-controller.yaml
  kubectl apply -f $PGPATH/opa/admission-controller.yaml --dry-run=true -o yaml | kubectl apply -f -

  CABUNDLE=$(cat opa/admission-ca.crt | base64 | tr -d '\n') \
    envsubst <$PGPATH/templates/opa-webhook-configuration.yaml >$PGPATH/opa/webhook-configuration.yaml
  kubectl apply -f $PGPATH/opa/webhook-configuration.yaml --dry-run=true -o yaml | kubectl apply -f -
}

create_namespace
whitelist_namsspace
create_tls_secret
deploy_opa

printf '\n%s\n' "###TASK-COMPLETED###"
