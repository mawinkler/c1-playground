#!/bin/bash

set -e

CLUSTER_NAME="$(yq '.cluster_name' $PGPATH/config.yaml | tr '[:upper:]' '[:lower:]')"
NAMESPACE_TRIVY="$(yq '.services[] | select(.name=="trivy") | .namespace' $PGPATH/config.yaml)"

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
  printf '%s' "Create trivy namespace"
  NAMESPACE=${NAMESPACE_TRIVY} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespaces for
# Trivy
# Globals:
#   NAMESPACE_TRIVY
# Arguments:
#   None
# Outputs:
#   None
#######################################
function whitelist_namespace() {
  printf '%s\n' "Whitelist namespaces"
  kubectl label namespace ${NAMESPACE_TRIVY} --overwrite ignoreAdmissionControl=true
}

#######################################
# Deploys Trivy to Kubernetes
# Globals:
#   NAMESPACE_TRIVY
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_trivy {
  printf '%s\n' "deploy trivy"

  mkdir -p $PGPATH/overrides
  envsubst <$PGPATH/templates/trivy-overrides.yaml >$PGPATH/overrides/trivy-overrides.yaml

  helm repo add aqua https://aquasecurity.github.io/helm-charts/
  helm repo update

  helm upgrade \
    trivy-operator \
    --values $PGPATH/overrides/trivy-overrides.yaml \
    --namespace trivy-system \
    --install \
    --set="trivy.ignoreUnfixed=true" \
    aqua/trivy-operator
}

create_namespace
whitelist_namespace
deploy_trivy

printf '\n%s\n' "###TASK-COMPLETED###"
