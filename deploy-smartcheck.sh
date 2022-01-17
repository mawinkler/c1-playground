#!/bin/bash

set -e

# Source helpers
. ./playground-helpers.sh

# Get config
SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
SC_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .username' config.json)"
SC_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .password' config.json)"
SC_HOSTNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .hostname' config.json)"
SC_LISTEN_PORT="$(jq -r '.services[] | select(.name=="smartcheck") | .proxy_listen_port' config.json)"
SC_REG_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_username' config.json)"
SC_REG_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_password' config.json)"
SC_REG_HOSTNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_hostname' config.json)"
SC_TEMPPW='justatemppw'

#######################################
# Creates Kubernetes namespace
# Globals:
#   SC_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_namespace() {
  # create namespace
  printf '%s' "Create smartcheck namespace"
  NAMESPACE=${SC_NAMESPACE} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Creates Smart Check overrides
# Globals:
#   SC_USERNAME
#   SC_TEMPPW
#   SERVICE_TYPE
#   SC_REG_USERNAME
#   SC_REG_PASSWORD
# Arguments:
#   None
# Outputs:
#   overrides/smartcheck-overrides.yaml
#   overrides/smartcheck-overrides-upgrade.yaml
#######################################
function create_smartcheck_overrides() {
  # create smart check overrides
  printf '%s' "Create smart check overrides"
  SC_USERNAME=${SC_USERNAME} \
    SC_TEMPPW=${SC_TEMPPW} \
    SERVICE_TYPE=${SERVICE_TYPE} \
    envsubst <templates/smartcheck-overrides.yaml >overrides/smartcheck-overrides.yaml

  SC_REG_USERNAME=${SC_REG_USERNAME} \
    SC_REG_PASSWORD=${SC_REG_PASSWORD} \
    envsubst <templates/smartcheck-overrides-upgrade.yaml >overrides/smartcheck-overrides-upgrade.yaml
  printf '%s\n' " 🍳"
}

#######################################
# Deploys Smart Check to Kubernetes
# Globals:
#   SC_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_smartcheck() {
  printf '%s\n' "Install smart check"
  helm upgrade --namespace ${SC_NAMESPACE} \
    --values overrides/smartcheck-overrides.yaml \
    smartcheck \
    --install \
    --reuse-values \
    https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz > /dev/null

  printf '%s' "Waiting for smart check to be in active state"
  SMARTCHECK_DEPLOYMENTS=$(kubectl -n smartcheck get deployments | grep -c "/")
  while [ $(kubectl -n smartcheck get deployments | grep -cE "1/1|2/2|3/3|4/4|5/5") -ne ${SMARTCHECK_DEPLOYMENTS} ]
  do
    printf '%s' "."
    sleep 2
  done
  printf '\n'
}

#######################################
# Upgrades Smart Check with certificate
# and pre-registry scanning
# Globals:
#   SC_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function upgrade_smartcheck() {
  printf '%s\n' "Upgrade smart check"
  helm upgrade --namespace ${SC_NAMESPACE} \
    --values overrides/smartcheck-overrides-upgrade.yaml \
    smartcheck \
    --reuse-values \
    https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz > /dev/null
}

#######################################
# Creates SSL certificate for linux
# playgrounds
# Globals:
#   SC_HOST
#   SC_NAMESPACE
# Arguments:
#   None
# Outputs:
#   certs/sc.crt
#   certs/sc.key
#######################################
function create_ssl_certificate_linux() {
  # create ssl certificate
  printf '%s' "Create ssl certificate (linux)"
  mkdir -p certs
  SC_HOST_IP=$(dig +short ${SC_HOST} | tail -n 1)
  cat <<EOF >certs/req-sc.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:${SC_HOST_IP//./-}.nip.io
EOF

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout certs/sc.key -out certs/sc.crt \
    -subj "/CN=${SC_HOST_IP//./-}.nip.io" -extensions san -config certs/req-sc.conf
  kubectl create secret tls k8s-certificate --cert=certs/sc.crt --key=certs/sc.key \
    --dry-run=client -n ${SC_NAMESPACE} -o yaml | kubectl apply -f - -o yaml
  printf '%s\n' " 🍵"
}

#######################################
# Creates SSL certificate for darwin
# playgrounds
# Globals:
#   SC_HOSTNAME
#   SC_REG_HOSTNAME
#   SC_NAMESPACE
# Arguments:
#   None
# Outputs:
#   certs/sc.crt
#   certs/sc.key
#######################################
function create_ssl_certificate_darwin() {
  # create ssl certificate
  printf '%s' "Create ssl certificate (darwin)"
  mkdir -p certs
  cat <<EOF >certs/req-sc.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:${SC_HOSTNAME},DNS:${SC_REG_HOSTNAME}
EOF

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout certs/sc.key -out certs/sc.crt \
    -subj "/CN=${SC_HOSTNAME}" -extensions san -config certs/req-sc.conf
  kubectl create secret tls k8s-certificate --cert=certs/sc.crt --key=certs/sc.key \
    --dry-run=client -n ${SC_NAMESPACE} -o yaml | kubectl apply -f - -o yaml
  printf '%s\n' " 🍵"
}

#######################################
# Executes initial password change
# Globals:
#   SC_HOST
#   SC_USERNAME
#   SC_TEMPPW
#   SC_USERID
#   SC_PASSWORD
# Arguments:
#   None
# Outputs:
#   None
#######################################
function password_change() {
  # initial password change
  printf '%s' "Executing initial password change"
  SC_BEARERTOKEN=""
  while [[ "${SC_BEARERTOKEN}" == "" ]]; do
    sleep 1
    SC_USERID=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                  --header @templates/smartcheck-header.txt \
                  -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_TEMPPW}'"}}' | \
                    jq '.user.id' | tr -d '"' 2>/dev/null)
    SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                      --header @templates/smartcheck-header.txt \
                      -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_TEMPPW}'"}}' | \
                        jq '.token' | tr -d '"' 2>/dev/null)
  done
  # create header
  SC_BEARERTOKEN=${SC_BEARERTOKEN} envsubst <templates/smartcheck-header-token.txt >overrides/smartcheck-header-token.txt
  X=$(curl -s -k -X POST https://${SC_HOST}/api/users/${SC_USERID}/password \
        --header @overrides/smartcheck-header-token.txt \
        -d '{"oldPassword":"'${SC_TEMPPW}'","newPassword":"'${SC_PASSWORD}'"}')
  printf '%s\n' " 🎀"
}

#######################################
# Creates Kubernetes ingress
# Globals:
#   SC_HOSTNAME
#   SC_REG_HOSTNAME
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_ingress() {
  printf '%s\n' "Create smart check ingress"
  SC_HOSTNAME=${SC_HOSTNAME} \
    SC_REG_HOSTNAME=${SC_REG_HOSTNAME} \
    envsubst <templates/smartcheck-ingress.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "Smart check ingress created 🍻"
}

#######################################
# Main:
# Implements two variants for Smart
# Check deployment depending on the
# host operating system
#######################################
if is_linux ; then
  SERVICE_TYPE='LoadBalancer'
  create_namespace
  create_smartcheck_overrides
  deploy_smartcheck
  get_smartcheck

  if [ "${SC_HOST}" == "" ]; then
    echo Unable to get Smart Check LoadBalancer
    exit -1
  else
    echo Smart Check on ${SC_HOST}
  fi

  echo $SC_HOST
  password_change
  create_ssl_certificate_linux
  upgrade_smartcheck

  # test if we're using a managed kubernetes cluster on GCP, Azure (or AWS)
  if is_gke || is_aks || is_eks ; then
    echo "Smart check UI on: https://${SC_HOST} w/ ${SC_USERNAME}/${SC_PASSWORD}" | tee -a services
  else
    ./deploy-proxy.sh smartcheck
    # echo "Registry login with: echo ${SC_REG_PASSWORD} | docker login https://$(hostname) -I | awk '{print $1}'):5000 --username ${SC_REG_USERNAME} --password-stdin" >> services
    echo "Smart check UI on: https://$(hostname) -I | awk '{print $1}'):${SC_LISTEN_PORT} w/ ${SC_USERNAME}/${SC_PASSWORD}" | tee -a services
  fi
fi

if is_darwin ; then
  if is_gke || is_aks || is_eks ; then
    SERVICE_TYPE='LoadBalancer'
    create_namespace
    create_smartcheck_overrides
    deploy_smartcheck
    get_smartcheck
    password_change
    create_ssl_certificate_linux
    upgrade_smartcheck
    echo "Smart check UI on: https://${SC_HOST} w/ ${SC_USERNAME}/${SC_PASSWORD}" | tee -a services
  else
    SERVICE_TYPE='ClusterIP'
    create_namespace
    create_smartcheck_overrides
    deploy_smartcheck
    get_smartcheck
    # SC_HOST="${SC_HOSTNAME}"
    create_ingress
    password_change
    create_ssl_certificate_darwin
    upgrade_smartcheck
    # echo "Registry login with: echo ${SC_REG_PASSWORD} | docker login ${SC_REG_HOSTNAME} --username ${SC_REG_USERNAME} --password-stdin" >> services
    echo "Smart check UI on: https://${SC_HOST} w/ ${SC_USERNAME}/${SC_PASSWORD}" | tee -a services
  fi
fi
