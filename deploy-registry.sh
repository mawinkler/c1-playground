#!/bin/bash

set -e

REG_NAMESPACE="$(jq -r '.registry_namespace' config.json)"
REG_NAME="$(jq -r '.registry_name' config.json)"
REG_SIZE="$(jq -r '.registry_size' config.json)"
REG_USERNAME="$(jq -r '.registry_username' config.json)"
REG_PASSWORD="$(jq -r '.registry_password' config.json)"

printf '%s' "configure registry namespace"

kubectl create namespace ${REG_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - > /dev/null

printf ' - %s\n' "configured"

# create auth secret
mkdir -p auth
docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn ${REG_USERNAME} ${REG_PASSWORD} > auth/htpasswd
kubectl --namespace ${REG_NAMESPACE} create secret generic auth-secret --from-file=auth/htpasswd

# create service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${REG_NAME}
  namespace: ${REG_NAMESPACE}
  labels:
    app: ${REG_NAME}
spec:
  type: LoadBalancer
  ports:
  - port: 5000
    protocol: TCP
    targetPort: 5000
  selector:
    app: ${REG_NAME}
EOF

# create tls secret
EXTERNAL_IP=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

mkdir -p certs
cat <<EOF >certs/req-reg.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:${EXTERNAL_IP//./-}.nip.io,IP:${EXTERNAL_IP}
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout certs/tls.key -out certs/tls.crt \
  -subj "/CN=${EXTERNAL_IP//./-}.nip.io" -extensions san -config certs/req-reg.conf &> /dev/null
kubectl --namespace ${REG_NAMESPACE} create secret tls certs-secret --cert=certs/tls.crt --key=certs/tls.key

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
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: repo-vol
          mountPath: "/var/lib/registry"
        - name: certs-vol
          mountPath: "/certs"
          readOnly: true
        - name: auth-vol
          mountPath: "/auth"
          readOnly: true
        env:
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

echo "login with: echo ${REG_PASSWORD} | docker login https://${EXTERNAL_IP//./-}.nip.io:5000 --username ${REG_USERNAME} --password-stdin"