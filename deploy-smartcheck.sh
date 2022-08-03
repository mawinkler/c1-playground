#!/bin/bash

set -e

# Source helpers
. ./playground-helpers.sh

STAGING=false

# Get config
CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
SC_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .username' config.json)"
SC_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .password' config.json)"
SC_HOSTNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .hostname' config.json)"
SC_LISTEN_PORT="$(jq -r '.services[] | select(.name=="smartcheck") | .proxy_listen_port' config.json)"
SC_REG_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_username' config.json)"
SC_REG_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_password' config.json)"
SC_REG_HOSTNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_hostname' config.json)"
SC_TEMPPW='justatemppw'
if [ "${STAGING}" = true ]; then
  API_KEY="$(jq -r '.services[] | select(.name=="staging-cloudone") | .api_key' config.json)"
  REGION="$(jq -r '.services[] | select(.name=="staging-cloudone") | .region' config.json)"
  INSTANCE="$(jq -r '.services[] | select(.name=="staging-cloudone") | .instance' config.json)"
else
  API_KEY="$(jq -r '.services[] | select(.name=="cloudone") | .api_key' config.json)"
  REGION="$(jq -r '.services[] | select(.name=="cloudone") | .region' config.json)"
  INSTANCE="$(jq -r '.services[] | select(.name=="cloudone") | .instance' config.json)"
fi

mkdir -p overrides

# Create API header
API_KEY=${API_KEY} envsubst <templates/cloudone-header.txt >overrides/cloudone-header.txt

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
# Whitelists Kubernetes namespace for
# Container Security
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function whitelist_namsspaces() {
  # whitelist some namespace for container security
  kubectl label namespace ${SC_NAMESPACE} --overwrite ignoreAdmissionControl=true
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
  # curl -s -L https://github.com/deep-security/smartcheck-helm/archive/refs/tags/1.2.68.tar.gz -o master-sc.tar.gz
  curl -s -L https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz -o master-sc.tar.gz
  helm upgrade --namespace ${SC_NAMESPACE} \
    --values overrides/smartcheck-overrides.yaml \
    smartcheck \
    --install \
    --reuse-values \
    master-sc.tar.gz > /dev/null

  printf '%s' "Waiting for smart check to be in active state"
  for i in {1..60} ; do
    sleep 2
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -n ${SC_NAMESPACE} | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -n ${SC_NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    if [[ $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ]] ; then
      break
    fi
    printf '%s' "."
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
    master-sc.tar.gz > /dev/null

  printf '%s' "Waiting for smart check to be in active state"
  for i in {1..60} ; do
    sleep 2
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -n ${SC_NAMESPACE} | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -n ${SC_NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    if [[ $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ]] ; then
      break
    fi
    printf '%s' "."
  done
  printf '\n'
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
    --dry-run=true -n ${SC_NAMESPACE} -o yaml | kubectl apply -f - -o yaml
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
    --dry-run=true -n ${SC_NAMESPACE} -o yaml | kubectl apply -f - -o yaml
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
  printf '%s\n' "Testing current password"
  SC_USERID=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                --header @templates/smartcheck-header.txt \
                -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_PASSWORD}'"}}' | \
                  jq '.user.id' 2>/dev/null | tr -d '"' 2>/dev/null)
  SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                    --header @templates/smartcheck-header.txt \
                    -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_PASSWORD}'"}}' | \
                      jq '.token' 2>/dev/null | tr -d '"' 2>/dev/null)
  if [[ "${SC_BEARERTOKEN}" == "" ]]; then
    printf '%s' "Executing initial password change"
    while [[ "${SC_BEARERTOKEN}" == "" ]]; do
      sleep 1
      SC_USERID=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                    --header @templates/smartcheck-header.txt \
                    -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_TEMPPW}'"}}' | \
                      jq '.user.id' 2>/dev/null | tr -d '"' 2>/dev/null)
      SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                        --header @templates/smartcheck-header.txt \
                        -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_TEMPPW}'"}}' | \
                          jq '.token' 2>/dev/null | tr -d '"' 2>/dev/null)
    done
    # create header
    SC_BEARERTOKEN=${SC_BEARERTOKEN} envsubst <templates/smartcheck-header-token.txt >overrides/smartcheck-header-token.txt
    X=$(curl -s -k -X POST https://${SC_HOST}/api/users/${SC_USERID}/password \
          --header @overrides/smartcheck-header-token.txt \
          -d '{"oldPassword":"'${SC_TEMPPW}'","newPassword":"'${SC_PASSWORD}'"}')
    printf '%s\n' " 🎀"
  else
    printf '%s\n' "Password already changed 🎀"
  fi
}

#######################################
# Creates a Scanner in Container
# Security using a locally installed
# Smart Check
# Globals:
#   CLUSTER_NAME
#   REGION
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_scanner() {
  SCANNER_ID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/scanners' \
    --header @overrides/cloudone-header.txt | \
    jq -r --arg CLUSTER_NAME ${CLUSTER_NAME//-/_} '.scanners[] | select(.name==$CLUSTER_NAME) | .id'
  )
  if [ "${SCANNER_ID}" != "" ] ; then
    printf '%s\n' "Reusing scanner with id ${SCANNER_ID}"
  fi
  if [ -f "overrides/container-security-overrides-image-security-bind.yaml" ] ; then
    printf '%s\n' "Reusing existing image security bind overrides"
  else
    printf '%s\n' "Create scanner object"
    RESULT=$(
      CLUSTER_NAME=${CLUSTER_NAME//-/_} \
        envsubst <templates/container-security-scanner.json |
          curl --silent --location --request POST 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/scanners' \
          --header @overrides/cloudone-header.txt \
          --data-binary "@-"
    )
    # bind smartcheck to container security
    API_KEY_SCANNER=$(echo ${RESULT} | jq -r ".apiKey") \
      REGION=${REGION} \
      INSTANCE=${INSTANCE} \
      envsubst <templates/container-security-overrides-image-security-bind.yaml >overrides/container-security-overrides-image-security-bind.yaml
  fi

  # create scanner
  printf '%s\n' "(Re-)bind smartcheck to container security"
  curl -s -L https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz -o master-sc.tar.gz
  helm upgrade \
    smartcheck \
    --reuse-values \
    --values overrides/container-security-overrides-image-security-bind.yaml \
    --namespace ${SC_NAMESPACE} \
    master-sc.tar.gz >/dev/null
}

#######################################
# Adds Playground registry to
# Smart Check
# Globals:
#   SC_HOST
#   SC_USERNAME
#   SC_PASSWORD
# Arguments:
#   None
# Outputs:
#   None
#######################################
function add_registry() {

  SC_USERID=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                --header @templates/smartcheck-header.txt \
                -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_PASSWORD}'"}}' | \
                  jq '.user.id' | tr -d '"' 2>/dev/null)
  SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                    --header @templates/smartcheck-header.txt \
                    -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_PASSWORD}'"}}' | \
                      jq '.token' | tr -d '"' 2>/dev/null)
  SC_BEARERTOKEN=${SC_BEARERTOKEN} envsubst <templates/smartcheck-header-token.txt >overrides/smartcheck-header-token.txt

  get_registry_credentials

  # if is_eks ; then
  #   SC_REPOID=$(curl -s -k -X POST https://${SC_HOST}/api/registries?scan=false \
  #                 --header @overrides/smartcheck-header-token.txt
  #                 -d '{"name":"Playground Registry","description":"","credentials":{"aws":{"region":"'${AWS_REGION}'"}},"insecureSkipVerify":true,"filter":{"include":["*"]},"schedule":true}"' | jq '.id')
  # else
  printf '%s\n' "Adding registry ${REGISTRY}"
  SC_REGID=$(curl -s -k -X POST https://${SC_HOST}/api/registries?scan=false \
                --header @overrides/smartcheck-header-token.txt \
                -d '{"name":"Playground Registry","description":"","host":"'${REGISTRY}'","credentials":{"username":"'${REGISTRY_USERNAME}'","password":"'${REGISTRY_PASSWORD}'"},"insecureSkipVerify":true,"filter":{"include":["*"]},"schedule":true}' | jq -r '.id')
  if [[ "${SC_REGID}" == "null" ]]; then
    printf '%s\n' "Registry already existing"
  else
    printf '%s\n' "Registry added with ID ${SC_REGID}"
  fi
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
  printf '%s\n' "Smart Check ingress created 🍻"
}

#######################################
# Main:
# Implements two variants for Smart
# Check deployment depending on the
# host operating system
#######################################
function main() {

  if is_linux ; then
    SERVICE_TYPE='LoadBalancer'
    create_namespace
    whitelist_namsspaces
    create_smartcheck_overrides
    deploy_smartcheck
    get_smartcheck

    if [ "${SC_HOST}" == "" ]; then
      printf '%s\n' "Unable to get Smart Check LoadBalancer"
      exit -1
    fi

    password_change
    create_ssl_certificate_linux
    upgrade_smartcheck
    create_scanner
    add_registry

    # test if we're using a managed kubernetes cluster on GCP, Azure (or AWS)
    if is_gke || is_aks || is_eks ; then
      printf '%s\n' "Smart check UI on: https://${SC_HOST} w/ ${SC_USERNAME}/${SC_PASSWORD}" | tee -a services
    else
      ./deploy-proxy.sh smartcheck
      # echo "Registry login with: echo ${SC_REG_PASSWORD} | docker login https://$(hostname) -I | awk '{print $1}'):5000 --username ${SC_REG_USERNAME} --password-stdin" | tee -a services
      printf '%s\n' "Smart check UI on: https://$(hostname -I | awk '{print $1}'):${SC_LISTEN_PORT} w/ ${SC_USERNAME}/${SC_PASSWORD}" | tee -a services
    fi
  fi

  if is_darwin ; then
    if is_gke || is_aks || is_eks ; then
      SERVICE_TYPE='LoadBalancer'
      create_namespace
      whitelist_namsspaces
      create_smartcheck_overrides
      deploy_smartcheck
      get_smartcheck
      password_change
      create_ssl_certificate_linux
      upgrade_smartcheck
      create_scanner
      add_registry
      printf '%s\n' "Smart check UI on: https://${SC_HOST} w/ ${SC_USERNAME}/${SC_PASSWORD}" | tee -a services
    else
      SERVICE_TYPE='ClusterIP'
      create_namespace
      whitelist_namsspaces
      create_smartcheck_overrides
      deploy_smartcheck
      get_smartcheck
      # SC_HOST="${SC_HOSTNAME}"
      create_ingress
      password_change
      create_ssl_certificate_darwin
      upgrade_smartcheck
      create_scanner
      add_registry
      # echo "Registry login with: echo ${SC_REG_PASSWORD} | docker login ${SC_REG_HOSTNAME} --username ${SC_REG_USERNAME} --password-stdin" | tee -a services
      printf '%s\n' "Smart check UI on: https://${SC_HOST} w/ ${SC_USERNAME}/${SC_PASSWORD}" | tee -a services
    fi
  fi
}

function cleanup() {
  helm -n ${SC_NAMESPACE} delete \
    smartcheck || true
  kubectl delete namespace ${SC_NAMESPACE}

  for i in {1..30} ; do
    sleep 2
    if [ "$(kubectl get all -n ${SC_NAMESPACE} | grep 'No resources found' || true)" == "" ] ; then
      return
    fi
  done
  false
}

function get_ui() {
  get_smartcheck
  UI_URL=https://${SC_HOST}
}

function test() {
  for i in {1..60} ; do
    sleep 5
    # test deployments and pods
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -n ${SC_NAMESPACE} | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -n ${SC_NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    PODS_TOTAL=$(kubectl get pods -n ${SC_NAMESPACE} | wc -l)
    PODS_READY=$(kubectl get pods -n ${SC_NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    if [[ ( $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ) && ( $((${PODS_TOTAL} - 1)) -eq ${PODS_READY} ) ]] ; then
      echo ${DEPLOYMENTS_READY}
      # test web app
      get_ui
      echo ${UI_URL}
      for i in {1..10} ; do
        sleep 2
        if [ $(curl -k --write-out '%{http_code}' --silent --output /dev/null ${UI_URL}) == 200 ] ; then
          return
        fi
      done
      return
    fi
  done
  false
}

function scan() {
  ./scan-image.sh nginx:latest
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi
