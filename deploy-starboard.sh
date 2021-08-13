#!/bin/bash

set -e

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
NAMESPACE_TRIVY="$(jq -r '.services[] | select(.name=="trivy") | .namespace' config.json)"
NAMESPACE_STARBOARD="$(jq -r '.services[] | select(.name=="starboard") | .namespace' config.json)"
OS="$(uname)"

function create_trivy_starboard_namespace {
  printf '%s' "Create trivy namespace"

  echo "---" >>up.log
  # create namespace
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE_TRIVY}
EOF
  printf '%s\n' " 🍼"

  printf '%s' "Create starboard namespace"
  echo "---" >>up.log
  # create namespace
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE_STARBOARD}
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspaces {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespaces
  kubectl label namespace ${NAMESPACE_TRIVY} --overwrite ignoreAdmissionControl=ignore
  kubectl label namespace ${NAMESPACE_STARBOARD} --overwrite ignoreAdmissionControl=ignore
}

# helm show values aquasecurity/trivy
function deploy_trivy_starboard {
  ## deploy trivy
  printf '%s\n' "deploy trivy and starboard"

  mkdir -p overrides
  cat <<EOF >overrides/overrides-trivy.yml
trivy:
  debugMode: true
EOF

  helm repo add aquasecurity https://aquasecurity.github.io/helm-charts/
  helm repo update

  # image:
  #   registry: docker.io
  #   repository: aquasec/trivy
  #   tag: 0.18.3
  #   pullPolicy: IfNotPresent
  #   pullSecret: ""
  IMAGEREF=$(helm show values aquasecurity/trivy --jsonpath='{.image.registry}/{.image.repository}:{.image.tag}')
  cat <<EOF >overrides/overrides-starboard.yml
targetNamespaces: ""
trivy:
  imageRef: ${IMAGEREF}
  mode: ClientServer
  serverURL: http://trivy.trivy:4954
EOF

  helm upgrade \
    trivy \
    --values overrides/overrides-trivy.yml \
    --namespace ${NAMESPACE_TRIVY} \
    --install \
    aquasecurity/trivy

  helm upgrade \
    starboard \
    --values overrides/overrides-starboard.yml \
    --namespace ${NAMESPACE_STARBOARD} \
    --install \
    aquasecurity/starboard-operator
}

create_trivy_starboard_namespace
whitelist_namsspaces
deploy_trivy_starboard
