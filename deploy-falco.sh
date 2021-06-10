#!/bin/bash

set -e

NAMESPACE="$(jq -r '.services[] | select(.name=="falco") | .namespace' config.json)"
OS="$(uname)"

function create_namespace {
  printf '%s' "Create falco namespace"

  echo "---" >>up.log
  # create service
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspace {
  printf '%s\n' "Whitelist namespace"

  # whitelist namespace for falco
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=ignore
}

function deploy_falco {
  ## deploy falco
  printf '%s\n' "deploy falco"

  helm repo add falcosecurity https://falcosecurity.github.io/charts
  helm repo update

  cat <<EOF > overrides/overrides-falco.yaml
auditLog:
  enabled: true
falcosidekick:
  enabled: true
  webui:
    enabled: true
    service:
      type: LoadBalancer
EOF

  # Install Falco
  helm -n ${NAMESPACE} install falco --values=overrides/overrides-falco.yaml falcosecurity/falco

  # Create NodePort Service to enable K8s Audit
  cat <<EOF | kubectl -n ${NAMESPACE} apply -f -
kind: Service
apiVersion: v1
metadata:
  name: falco-np
spec:
  selector:
    app: falco
  ports:
  - protocol: TCP
    port: 8765
    nodePort: 32765
  type: NodePort
EOF
}

create_namespace
whitelist_namsspace
deploy_falco

if [ "${OS}" == 'Linux' ]; then
  ./deploy-proxy.sh falco
fi