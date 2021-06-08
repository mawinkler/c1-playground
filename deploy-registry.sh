#!/bin/bash

set -e

REG_NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' config.json)"
REG_NAME=playground-registry
REG_HOSTNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .hostname' config.json)"
REG_SIZE="$(jq -r '.services[] | select(.name=="playground-registry") | .size' config.json)"
REG_USERNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .username' config.json)"
REG_PASSWORD="$(jq -r '.services[] | select(.name=="playground-registry") | .password' config.json)"
OS="$(uname)"

function create_namespace_service {
  printf '%s' "Create registry namespace and service"

  echo "---" >> up.log
  # create service
  cat <<EOF | kubectl apply -f - -o yaml | cat >> up.log
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
  type: ${SERVICE_TYPE}
  ports:
  - port: 5000
    protocol: TCP
    targetPort: 5000
  selector:
    app: ${REG_NAME}
EOF
  printf '%s\n' " 🍼"
}

function create_auth_secret {
  # create auth secret

  printf '%s' "Create registry auth secret"

  mkdir -p auth
  docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn ${REG_USERNAME} ${REG_PASSWORD} > auth/htpasswd
  echo "---" >> up.log
  kubectl --namespace ${REG_NAMESPACE} create secret generic auth-secret --from-file=auth/htpasswd \
    -o yaml | cat >> up.log
  printf '%s\n' " 🍿"
}

function create_tls_secret_linux {
  # create tls secret

  printf '%s' "Create registry tls secret (linux)"

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
    -subj "/CN=${EXTERNAL_IP}" -extensions san -config certs/req-reg.conf &> /dev/null
  echo "---" >> up.log
  kubectl --namespace ${REG_NAMESPACE} create secret tls certs-secret --cert=certs/tls.crt --key=certs/tls.key \
    -o yaml | cat >> up.log
  printf '%s\n' " 🍵"
}

function create_tls_secret_darwin {
  # create tls secret

  printf '%s' "create tls secret (darwin)"

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
  echo "---" >> up.log
  kubectl --namespace ${REG_NAMESPACE} create secret tls certs-secret --cert=certs/tls.crt --key=certs/tls.key \
    -o yaml | cat >> up.log
  printf '%s\n' " 🍵"
}

function create_deployment {
  # create registry deployment

  printf '%s' "Create registry deployment"

  echo "---" >> up.log
  cat <<EOF | kubectl apply -f - -o yaml | cat >> up.log
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
  printf '%s\n' " 🍶"
}

function create_ingress {
  # create ingress for registry

  # cat <<EOF | kubectl apply -f -
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
  # EOF

  printf '%s\n' "Create registry ingress"

  echo "---" >> up.log
  cat <<EOF | kubectl apply -f - -o yaml | cat >> up.log
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
    - ${REG_HOSTNAME}
    #secretName: certs-secret
  rules:
  - host: ${REG_HOSTNAME}
    http:
      paths:
      - backend:
          serviceName: ${REG_NAME}
          servicePort: 5000
        path: /
EOF
  printf '%s\n' "Registry ingress created 🍻"
}

if [ "${OS}" == 'Linux' ]; then
  SERVICE_TYPE='LoadBalancer'
  create_namespace_service
  create_auth_secret
  create_tls_secret_linux
  create_deployment
  echo "Registry login with: echo ${REG_PASSWORD} | docker login https://${EXTERNAL_IP}:5000 --username ${REG_USERNAME} --password-stdin"
fi

if [ "${OS}" == 'Darwin' ]; then
  SERVICE_TYPE='ClusterIP'
  create_namespace_service
  create_auth_secret
  create_tls_secret_darwin
  create_deployment
  create_ingress
  echo "Registry login with: echo ${REG_PASSWORD} | docker login ${REG_HOSTNAME} --username ${REG_USERNAME} --password-stdin"
fi
