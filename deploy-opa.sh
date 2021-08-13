#!/bin/bash

set -e

NAMESPACE="$(jq -r '.services[] | select(.name=="opa") | .namespace' config.json)"
OS="$(uname)"

mkdir -p opa

function create_opa_namespace {
  printf '%s' "Create opa namespace"

  echo "---" >>up.log
  # create namespace
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
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
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=ignore
  kubectl label namespace ${NAMESPACE} --overwrite openpolicyagent.org/webhook=ignore
  kubectl label namespace kube-system  --overwrite openpolicyagent.org/webhook=ignore
}

function create_tls_secret {
  # create tls secret
  printf '%s' "Create opa webhook server tls secret"

  cat <<EOF >opa/webhook-server-tls.conf
[req]
  req_extensions = v3_req
  distinguished_name = req_distinguished_name
  prompt = no
[req_distinguished_name]
  CN = opa.opa.svc
[ v3_req ]
  basicConstraints = CA:FALSE
  keyUsage = nonRepudiation, digitalSignature, keyEncipherment
  extendedKeyUsage = clientAuth, serverAuth
  subjectAltName = @alt_names
[alt_names]
  DNS.1 = opa.opa.svc
EOF

  openssl genrsa -out opa/admission-ca.key 2048
  openssl req -x509 -new -nodes -key opa/admission-ca.key -days 100000 -out opa/admission-ca.crt -subj "/CN=admission_ca"

  openssl genrsa -out opa/webhook-server-tls.key 2048
  openssl req -new -key opa/webhook-server-tls.key -out opa/webhook-server-tls.csr -config opa/webhook-server-tls.conf
  openssl x509 -req -in opa/webhook-server-tls.csr -CA opa/admission-ca.crt -CAkey opa/admission-ca.key -CAcreateserial -out opa/webhook-server-tls.crt -days 100000 -extensions v3_req -extfile opa/webhook-server-tls.conf

  kubectl -n opa create secret tls opa-server --cert=opa/webhook-server-tls.crt --key=opa/webhook-server-tls.key

  printf '%s\n' " 🍵"
}

function deploy_opa {
  ## deploy opa
  printf '%s\n' "deploy opa"

  cat <<EOF >opa/admission-controller.yaml
# Grant OPA/kube-mgmt read-only access to resources. This lets kube-mgmt
# replicate resources into OPA so they can be used in policies.
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: opa-viewer
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  name: system:serviceaccounts:opa
  apiGroup: rbac.authorization.k8s.io
---
# Define role for OPA/kube-mgmt to update configmaps with policy status.
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: opa
  name: configmap-modifier
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["update", "patch"]
---
# Grant OPA/kube-mgmt role defined above.
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: opa
  name: opa-configmap-modifier
roleRef:
  kind: Role
  name: configmap-modifier
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  name: system:serviceaccounts:opa
  apiGroup: rbac.authorization.k8s.io
---
kind: Service
apiVersion: v1
metadata:
  name: opa
  namespace: opa
spec:
  selector:
    app: opa
  ports:
  - name: https
    protocol: TCP
    port: 443
    targetPort: 8443
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: opa
  namespace: opa
  name: opa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opa
  template:
    metadata:
      labels:
        app: opa
      name: opa
    spec:
      containers:
        # WARNING: OPA is NOT running with an authorization policy configured. This
        # means that clients can read and write policies in OPA. If you are
        # deploying OPA in an insecure environment, be sure to configure
        # authentication and authorization on the daemon. See the Security page for
        # details: https://www.openpolicyagent.org/docs/security.html.
        - name: opa
          image: openpolicyagent/opa:0.31.0-rootless
          args:
            - "run"
            - "--server"
            - "--tls-cert-file=/certs/tls.crt"
            - "--tls-private-key-file=/certs/tls.key"
            - "--addr=0.0.0.0:8443"
            - "--addr=http://127.0.0.1:8181"
            - "--log-format=json-pretty"
            - "--set=decision_logs.console=true"
          volumeMounts:
            - readOnly: true
              mountPath: /certs
              name: opa-server
          readinessProbe:
            httpGet:
              path: /health?plugins&bundle
              scheme: HTTPS
              port: 8443
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              scheme: HTTPS
              port: 8443
            initialDelaySeconds: 3
            periodSeconds: 5
        - name: kube-mgmt
          image: openpolicyagent/kube-mgmt:0.11
          args:
            - "--replicate-cluster=v1/namespaces"
            - "--replicate=extensions/v1beta1/ingresses"
      volumes:
        - name: opa-server
          secret:
            secretName: opa-server
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: opa-default-system-main
  namespace: opa
data:
  main: |
    package system

    import data.kubernetes.admission

    main = {
      "apiVersion": "admission.k8s.io/v1beta1",
      "kind": "AdmissionReview",
      "response": response,
    }

    default uid = ""

    uid = input.request.uid

    response = {
        "allowed": false,
        "uid": uid,
        "status": {
            "reason": reason,
        },
    } {
        reason = concat(", ", admission.deny)
        reason != ""
    }
    else = {"allowed": true, "uid": uid}
EOF

  kubectl apply -f opa/admission-controller.yaml --dry-run=client -o yaml | kubectl apply -f -

  cat <<EOF >opa/webhook-configuration.yaml
kind: ValidatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1beta1
metadata:
  name: opa-validating-webhook
webhooks:
  - name: validating-webhook.openpolicyagent.org
    namespaceSelector:
      matchExpressions:
      - key: openpolicyagent.org/webhook
        operator: NotIn
        values:
        - ignore
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: ["*"]
        apiVersions: ["*"]
        resources: ["*"]
    clientConfig:
      caBundle: $(cat opa/admission-ca.crt | base64 | tr -d '\n')
      service:
        namespace: opa
        name: opa
EOF

  kubectl apply -f opa/webhook-configuration.yaml --dry-run=client -o yaml | kubectl apply -f -
}

create_opa_namespace
whitelist_namsspaces
create_tls_secret
deploy_opa
