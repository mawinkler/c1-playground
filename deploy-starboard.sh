#!/bin/bash

set -e

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
NAMESPACE_TRIVY="$(jq -r '.services[] | select(.name=="trivy") | .namespace' config.json)"
NAMESPACE_STARBOARD="$(jq -r '.services[] | select(.name=="starboard") | .namespace' config.json)"

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
  NAMESPACE=${NAMESPACE_TRIVY} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
  printf '%s' "Create starboard namespace"
  NAMESPACE=${NAMESPACE_STARBOARD} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespaces for
# Trivy and Starboard
# Globals:
#   NAMESPACE_TRIVY
#   NAMESPACE_STARBOARD
# Arguments:
#   None
# Outputs:
#   None
#######################################
function whitelist_namespace() {
  printf '%s\n' "Whitelist namespaces"
  kubectl label namespace ${NAMESPACE_TRIVY} --overwrite ignoreAdmissionControl=true
  kubectl label namespace ${NAMESPACE_STARBOARD} --overwrite ignoreAdmissionControl=true
}

# helm show values aquasecurity/trivy
#######################################
# Deploys Trivy and Starboard to
# Kubernetes
# Globals:
#   NAMESPACE_TRIVY
#   NAMESPACE_STARBOARD
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_trivy_starboard {
  printf '%s\n' "deploy trivy and starboard"

  mkdir -p overrides
  envsubst <templates/trivy-overrides.yaml >overrides/trivy-overrides.yaml
  helm repo add aquasecurity https://aquasecurity.github.io/helm-charts/
  helm repo update
  # image:
  #   registry: docker.io
  #   repository: aquasec/trivy
  #   tag: 0.18.3
  #   pullPolicy: IfNotPresent
  #   pullSecret: ""
  # IMAGEREF=$(helm show values aquasecurity/trivy --jsonpath='{.image.registry}/{.image.repository}:{.image.tag}') \
  IMAGEREF=$(helm show values aquasecurity/trivy --jsonpath='{.image.registry}/{.image.repository}') \
    envsubst <templates/starboard-overrides.yaml >overrides/starboard-overrides.yaml

  # helm upgrade \
  #   trivy \
  #   --values overrides/trivy-overrides.yaml \
  #   --namespace ${NAMESPACE_TRIVY} \
  #   --install \
  #   aquasecurity/trivy
  helm upgrade \
    trivy-operator \
    --values overrides/trivy-overrides.yaml \
    --namespace ${NAMESPACE_TRIVY} \
    --create-namespace \
    --install \
    aquasecurity/trivy-operator
  helm upgrade \
    starboard-operator \
    --values overrides/starboard-overrides.yaml \
    --namespace ${NAMESPACE_STARBOARD} \
    --install \
    aquasecurity/starboard-operator
}

create_namespace
whitelist_namespace
deploy_trivy_starboard

# krew
kubectl krew install starboard
