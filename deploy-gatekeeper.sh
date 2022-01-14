#!/bin/bash

set -e

NAMESPACE="$(jq -r '.services[] | select(.name=="gatekeeper") | .namespace' config.json)"
OS="$(uname)"

mkdir -p gatekeeper

function create_gatekeeper_namespace {
  printf '%s' "Create gatekeeper namespace"

  # create namespace
  cat <<EOF | kubectl apply -f - -o yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspaces {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespaces
  # kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=true
  # kubectl label namespace ${NAMESPACE} --overwrite openpolicyagent.org/webhook=ignore
  # kubectl label namespace kube-system  --overwrite openpolicyagent.org/webhook=ignore
}

function create_tls_secret {
  # create tls secret
  printf '%s' "Create gatekeeper webhook server tls secret"

  cat <<EOF >gatekeeper/webhook-server-tls.conf
[req]
  req_extensions = v3_req
  distinguished_name = req_distinguished_name
  prompt = no
[req_distinguished_name]
  CN = gatekeeper.gatekeeper.svc
[ v3_req ]
  basicConstraints = CA:FALSE
  keyUsage = nonRepudiation, digitalSignature, keyEncipherment
  extendedKeyUsage = clientAuth, serverAuth
  subjectAltName = @alt_names
[alt_names]
  DNS.1 = gatekeeper.gatekeeper.svc
EOF

  openssl genrsa -out gatekeeper/admission-ca.key 2048
  openssl req -x509 -new -nodes -key gatekeeper/admission-ca.key -days 100000 -out gatekeeper/admission-ca.crt -subj "/CN=admission_ca"

  openssl genrsa -out gatekeeper/webhook-server-tls.key 2048
  openssl req -new -key gatekeeper/webhook-server-tls.key -out gatekeeper/webhook-server-tls.csr -config gatekeeper/webhook-server-tls.conf
  openssl x509 -req -in gatekeeper/webhook-server-tls.csr -CA gatekeeper/admission-ca.crt -CAkey gatekeeper/admission-ca.key -CAcreateserial -out gatekeeper/webhook-server-tls.crt -days 100000 -extensions v3_req -extfile gatekeeper/webhook-server-tls.conf

  kubectl -n gatekeeper create secret tls gatekeeper-server --cert=gatekeeper/webhook-server-tls.crt --key=gatekeeper/webhook-server-tls.key

  printf '%s\n' " 🍵"
}

function deploy_gatekeeper {
  ## deploy gatekeeper
  printf '%s\n' "deploy gatekeeper"

  cat <<EOF >overrides/overrides-gatekeeper.yml
replicas: 3
auditInterval: 60
auditMatchKindOnly: false
constraintViolationsLimit: 20
auditFromCache: false
disableValidatingWebhook: false
validatingWebhookTimeoutSeconds: 3
validatingWebhookFailurePolicy: Ignore
validatingWebhookCheckIgnoreFailurePolicy: Fail
enableDeleteOperations: false
experimentalEnableMutation: false
auditChunkSize: 0
logLevel: INFO
logDenies: false
emitAdmissionEvents: false
emitAuditEvents: false
resourceQuota: true
# postInstall:
#   labelNamespace:
#     enabled: true
#     image:
#       repository: line/kubectl-kustomize
#       tag: 1.20.4-4.0.5
#       pullPolicy: IfNotPresent
#       pullSecrets: []
# image:
#   repository: openpolicyagent/gatekeeper
#   release: v3.6.0-beta.3
#   pullPolicy: IfNotPresent
#   pullSecrets: []
# podAnnotations:
#   { container.seccomp.security.alpha.kubernetes.io/manager: runtime/default }
# podLabels: {}
# podCountLimit: 100
# secretAnnotations: {}
# controllerManager:
#   exemptNamespaces: []
#   hostNetwork: false
#   priorityClassName: system-cluster-critical
#   affinity:
#     podAntiAffinity:
#       preferredDuringSchedulingIgnoredDuringExecution:
#         - podAffinityTerm:
#             labelSelector:
#               matchExpressions:
#                 - key: gatekeeper.sh/operation
#                   operator: In
#                   values:
#                     - webhook
#             topologyKey: kubernetes.io/hostname
#           weight: 100
#   tolerations: []
#   nodeSelector: { kubernetes.io/os: linux }
#   resources:
#     limits:
#       cpu: 1000m
#       memory: 512Mi
#     requests:
#       cpu: 100m
#       memory: 256Mi
# audit:
#   hostNetwork: false
#   priorityClassName: system-cluster-critical
#   affinity: {}
#   tolerations: []
#   nodeSelector: { kubernetes.io/os: linux }
#   resources:
#     limits:
#       cpu: 1000m
#       memory: 512Mi
#     requests:
#       cpu: 100m
#       memory: 256Mi
# pdb:
#   controllerManager:
#     minAvailable: 1
# service: {}
# disabledBuiltins:
EOF

  helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
  helm upgrade \
    gatekeeper \
    --values overrides/overrides-gatekeeper.yml \
    --namespace ${NAMESPACE} \
    --install \
    gatekeeper/gatekeeper
}

create_gatekeeper_namespace
whitelist_namsspaces
# create_tls_secret
deploy_gatekeeper
