#!/bin/bash

set -e

REG_NAMESPACE="$(jq -r '.registry_namespace' config.json)"
REG_NAME="$(jq -r '.registry_name' config.json)"
REG_SIZE="$(jq -r '.registry_size' config.json)"
REG_USERNAME="$(jq -r '.registry_username' config.json)"
REG_PASSWORD="$(jq -r '.registry_password' config.json)"
REG_HOSTNAME="$(jq -r '.registry_hostname' config.json)"

kubectl -n registry delete deployment playground-registry
kubectl -n registry delete svc playground-registry
kubectl -n registry delete ingress playground-registry
kubectl delete ns registry

printf '%s' "create namespace and service"

# create namespace and service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${REG_NAMESPACE}
---
apiVersion: v1
kind: Service
metadata:
  name: ${REG_NAME}
  namespace: ${REG_NAMESPACE}
  labels:
    app: ${REG_NAME}
spec:
  ports:
  - name: http
    port: 5000
    targetPort: 5000
  selector:
    app: ${REG_NAME}
EOF

printf '%s' "create auth secret"

# create auth secret
mkdir -p auth
docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn ${REG_USERNAME} ${REG_PASSWORD} > auth/htpasswd
kubectl --namespace ${REG_NAMESPACE} create secret generic auth-secret --from-file=auth/htpasswd

printf '%s' "create tls secret"

# create tls secret
mkdir -p certs
cat <<EOF >certs/req-reg.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:${REG_HOSTNAME}
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout certs/tls.key -out certs/tls.crt \
  -subj "/CN=${REG_HOSTNAME}" -extensions san -config certs/req-reg.conf &> /dev/null
kubectl --namespace ${REG_NAMESPACE} create secret tls certs-secret --cert=certs/tls.crt --key=certs/tls.key

printf '%s' "create deployment"

# create the rest
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: docker-repo-pvc
  namespace: ${REG_NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${REG_SIZE}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${REG_NAME}
  namespace: ${REG_NAMESPACE}
  labels:
    app: ${REG_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${REG_NAME}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: ${REG_NAME}
    spec:
      containers:
        - name: ${REG_NAME}
          image: registry:2.6.2
          env:
            - name: REGISTRY_HTTP_ADDR
              value: ":5000"
            - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
              value: "/var/lib/registry"
            - name: REGISTRY_AUTH
              value: "htpasswd"
            - name: REGISTRY_AUTH_HTPASSWD_REALM
              value: "Registry Realm"
            - name: REGISTRY_AUTH_HTPASSWD_PATH
              value: "/auth/htpasswd"
            - name: REGISTRY_HTTP_TLS_CERTIFICATE
              value: "/certs/tls.crt"
            - name: REGISTRY_HTTP_TLS_KEY
              value: "/certs/tls.key"
          ports:
          - name: http
            containerPort: 5000
          volumeMounts:
          - name: repo-vol
            mountPath: "/var/lib/registry"
          - name: certs-vol
            mountPath: "/certs"
            readOnly: true
          - name: auth-vol
            mountPath: "/auth"
            readOnly: true
      volumes:
        - name: repo-vol
          persistentVolumeClaim:
            claimName: docker-repo-pvc
        - name: certs-vol
          secret:
            secretName: certs-secret
        - name: auth-vol
          secret:
            secretName: auth-secret
EOF

echo "login with: echo ${REG_PASSWORD} | docker login https://${EXTERNAL_IP}:5000 --username ${REG_USERNAME} --password-stdin"

printf '%s' "create ingress"

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    # nginx.ingress.kubernetes.io/proxy-body-size: "0"
    # nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    # nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"
    # kubernetes.io/tls-acme: 'true'
  name: ${REG_NAME}
  namespace: ${REG_NAMESPACE}
spec:
  tls:
  - hosts:
    - registry.localdomain
    #secretName: certs-secret
  rules:
  - host: registry.localdomain
    http:
      paths:
      - backend:
          serviceName: ${REG_NAME}
          servicePort: 5000
        path: /

# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: registry
#   namespace: registry
# spec:
#   rules:
#   - http:
#       paths:
#         - pathType: ImplementationSpecific
#           backend:
#             service:
#               name: playground-registry
#               port:
#                 number: 5000
EOF
