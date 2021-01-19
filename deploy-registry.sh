#!/bin/bash

set -e

REG_NAMESPACE=registry
REG_NAME=registry2
REG_SIZE=10Gi
REG_USERNAME=admin
REG_PASSWORD=trendmicro

# create auth secret
mkdir -p auth
docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn ${REG_USERNAME} ${REG_PASSWORD} > auth/htpasswd
kubectl create secret generic auth-secret --from-file=auth/htpasswd

# create service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${REG_NAME}
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
EXTERNAL_IP=$(kubectl get svc ${REG_NAME} \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Registry IP: ${EXTERNAL_IP}"

mkdir -p certs
cat <<EOF >certs/req.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:${EXTERNAL_IP//./-}.nip.io,IP:${EXTERNAL_IP}
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout certs/tls.key -out certs/tls.crt \
  -subj "/CN=${EXTERNAL_IP//./-}.nip.io" -extensions san -config certs/req.conf &> /dev/null
kubectl create secret tls certs-secret --cert=certs/tls.crt --key=certs/tls.key

# create the rest
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: docker-repo-pvc
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

echo "Login with: echo ${REG_PASSWORD} | docker login https://${EXTERNAL_IP//./-}.nip.io:5000 --username ${REG_USERNAME} --password-stdin"