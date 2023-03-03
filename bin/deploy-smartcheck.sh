#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

STAGING=false

# Get config
CLUSTER_NAME="$(yq '.cluster_name' $PGPATH/config.yaml)"
SC_NAMESPACE="$(yq '.services[] | select(.name=="smartcheck") | .namespace' $PGPATH/config.yaml)"
SC_USERNAME="$(yq '.services[] | select(.name=="smartcheck") | .username' $PGPATH/config.yaml)"
SC_PASSWORD="$(yq '.services[] | select(.name=="smartcheck") | .password' $PGPATH/config.yaml)"
SC_HOSTNAME="$(yq '.services[] | select(.name=="smartcheck") | .hostname' $PGPATH/config.yaml)"
SC_LISTEN_PORT="$(yq '.services[] | select(.name=="smartcheck") | .proxy_listen_port' $PGPATH/config.yaml)"
SC_REG_USERNAME="$(yq '.services[] | select(.name=="smartcheck") | .reg_username' $PGPATH/config.yaml)"
SC_REG_PASSWORD="$(yq '.services[] | select(.name=="smartcheck") | .reg_password' $PGPATH/config.yaml)"
SC_REG_HOSTNAME="$(yq '.services[] | select(.name=="smartcheck") | .reg_hostname' $PGPATH/config.yaml)"
SC_TEMPPW='justatemppw'
API_KEY="$(yq '.services[] | select(.name=="cloudone") | .api_key' $PGPATH/config.yaml)"
REGION="$(yq '.services[] | select(.name=="cloudone") | .region' $PGPATH/config.yaml)"
INSTANCE="$(yq '.services[] | select(.name=="cloudone") | .instance' $PGPATH/config.yaml)"
if [ ${INSTANCE} = null ]; then
  INSTANCE=cloudone
fi

mkdir -p $PGPATH/overrides

# Create API header
API_KEY=${API_KEY} envsubst <$PGPATH/templates/cloudone-header.txt >$PGPATH/overrides/cloudone-header.txt

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
  NAMESPACE=${SC_NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
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
    envsubst <$PGPATH/templates/smartcheck-overrides.yaml >$PGPATH/overrides/smartcheck-overrides.yaml

  SC_REG_USERNAME=${SC_REG_USERNAME} \
    SC_REG_PASSWORD=${SC_REG_PASSWORD} \
    envsubst <$PGPATH/templates/smartcheck-overrides-upgrade.yaml >$PGPATH/overrides/smartcheck-overrides-upgrade.yaml
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
  curl -s -L https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz -o $PGPATH/master-sc.tar.gz
  helm upgrade --namespace ${SC_NAMESPACE} \
    --values $PGPATH/overrides/smartcheck-overrides.yaml \
    smartcheck \
    --install \
    --reuse-values \
    $PGPATH/master-sc.tar.gz > /dev/null

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
    --values $PGPATH/overrides/smartcheck-overrides-upgrade.yaml \
    smartcheck \
    --reuse-values \
    $PGPATH/master-sc.tar.gz > /dev/null

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
  mkdir -p $PGPATH/certs
  SC_HOST_IP=$(dig +short ${SC_HOST} | tail -n 1)
  cat <<EOF >$PGPATH/certs/req-sc.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:${SC_HOST_IP//./-}.nip.io
EOF

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout $PGPATH/certs/sc.key -out $PGPATH/certs/sc.crt \
    -subj "/CN=${SC_HOST_IP//./-}.nip.io" -extensions san -config $PGPATH/certs/req-sc.conf
  kubectl create secret tls k8s-certificate --cert=$PGPATH/certs/sc.crt --key=$PGPATH/certs/sc.key \
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
  mkdir -p $PGPATH/certs
  cat <<EOF >$PGPATH/certs/req-sc.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:${SC_HOSTNAME},DNS:${SC_REG_HOSTNAME}
EOF

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout $PGPATH/certs/sc.key -out $PGPATH/certs/sc.crt \
    -subj "/CN=${SC_HOSTNAME}" -extensions san -config $PGPATH/certs/req-sc.conf
  kubectl create secret tls k8s-certificate --cert=$PGPATH/certs/sc.crt --key=$PGPATH/certs/sc.key \
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
                --header @$PGPATH/templates/smartcheck-header.txt \
                -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_PASSWORD}'"}}' | \
                  jq '.user.id' 2>/dev/null | tr -d '"' 2>/dev/null)
  SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                    --header @$PGPATH/templates/smartcheck-header.txt \
                    -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_PASSWORD}'"}}' | \
                      jq '.token' 2>/dev/null | tr -d '"' 2>/dev/null)
  if [[ "${SC_BEARERTOKEN}" == "" ]]; then
    printf '%s' "Executing initial password change"
    while [[ "${SC_BEARERTOKEN}" == "" ]]; do
      sleep 1
      SC_USERID=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                    --header @$PGPATH/templates/smartcheck-header.txt \
                    -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_TEMPPW}'"}}' | \
                      jq '.user.id' 2>/dev/null | tr -d '"' 2>/dev/null)
      SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                        --header @$PGPATH/templates/smartcheck-header.txt \
                        -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_TEMPPW}'"}}' | \
                          jq '.token' 2>/dev/null | tr -d '"' 2>/dev/null)
    done
    # create header
    SC_BEARERTOKEN=${SC_BEARERTOKEN} envsubst <$PGPATH/templates/smartcheck-header-token.txt >$PGPATH/overrides/smartcheck-header-token.txt
    X=$(curl -s -k -X POST https://${SC_HOST}/api/users/${SC_USERID}/password \
          --header @$PGPATH/overrides/smartcheck-header-token.txt \
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
  printf '%s\n' "Create scanner object"
  RESULT=$(
    CLUSTER_NAME=${CLUSTER_NAME//-/_}_$(openssl rand -hex 4) \
      envsubst <$PGPATH/templates/container-security-scanner.json |
        curl --silent --location --request POST 'https://container.'${REGION}'.'${INSTANCE}'.trendmicro.com/api/scanners' \
        --header @$PGPATH/overrides/cloudone-header.txt \
        --data-binary "@-"
  )
  # bind smartcheck to container security
  API_KEY_SCANNER=$(echo ${RESULT} | jq -r ".apiKey") \
    REGION=${REGION} \
    INSTANCE=${INSTANCE} \
    envsubst <$PGPATH/templates/container-security-overrides-image-security-bind.yaml >$PGPATH/overrides/container-security-overrides-image-security-bind.yaml

  # create scanner
  printf '%s\n' "(Re-)bind smartcheck to container security"
  # curl -s -L https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz -o $PGPATH/master-sc.tar.gz
  helm upgrade \
    smartcheck \
    --reuse-values \
    --values $PGPATH/overrides/container-security-overrides-image-security-bind.yaml \
    --namespace ${SC_NAMESPACE} \
    $PGPATH/master-sc.tar.gz >/dev/null
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
                --header @$PGPATH/templates/smartcheck-header.txt \
                -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_PASSWORD}'"}}' | \
                  jq '.user.id' | tr -d '"' 2>/dev/null)
  SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                    --header @$PGPATH/templates/smartcheck-header.txt \
                    -d '{"user":{"userid":"'${SC_USERNAME}'","password":"'${SC_PASSWORD}'"}}' | \
                      jq '.token' | tr -d '"' 2>/dev/null)
  SC_BEARERTOKEN=${SC_BEARERTOKEN} envsubst <$PGPATH/templates/smartcheck-header-token.txt >$PGPATH/overrides/smartcheck-header-token.txt

  get_registry_credentials

  # if is_eks ; then
  #   SC_REPOID=$(curl -s -k -X POST https://${SC_HOST}/api/registries?scan=false \
  #                 --header @$PGPATH/overrides/smartcheck-header-token.txt
  #                 -d '{"name":"Playground Registry","description":"","credentials":{"aws":{"region":"'${AWS_REGION}'"}},"insecureSkipVerify":true,"filter":{"include":["*"]},"schedule":true}"' | jq '.id')
  # else
  printf '%s\n' "Adding registry ${REGISTRY}"
  SC_REGID=$(curl -s -k -X POST https://${SC_HOST}/api/registries?scan=false \
                --header @$PGPATH/overrides/smartcheck-header-token.txt \
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
    envsubst <$PGPATH/templates/smartcheck-ingress.yaml | kubectl apply -f - -o yaml
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
      echo "Smart Check: https://${SC_HOST}" | tee -a $PGPATH/services
      echo "  U/P: ${SC_USERNAME} / ${SC_PASSWORD}" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
    else
      $PGPATH/bin/deploy-proxy.sh smartcheck
      # echo "Registry login with: echo ${SC_REG_PASSWORD} | docker login https://$(hostname) -I | awk '{print $1}'):5000 --username ${SC_REG_USERNAME} --password-stdin" | tee -a services
      echo "Smart Check: $(hostname -I | awk '{print $1}'):${SC_LISTEN_PORT}" | tee -a $PGPATH/services
      echo "  U/P: ${SC_USERNAME} / ${SC_PASSWORD}" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
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
      echo "Smart Check: https://${SC_HOST}" | tee -a $PGPATH/services
      echo "  U/P: ${SC_USERNAME} / ${SC_PASSWORD}" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
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
      echo "Smart Check: https://${SC_HOST}" | tee -a $PGPATH/services
      echo "  U/P: ${SC_USERNAME} / ${SC_PASSWORD}" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
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

printf '\n%s\n' "###TASK-COMPLETED###"
