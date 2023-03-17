#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
VICTIMS_NAMESPACE="$(yq '.services[] | select(.name=="demo-java-goof") | .namespace' $PGPATH/config.yaml)"
DEMO_JAVA_GOOF_LISTEN_PORT="$(yq '.services[] | select(.name=="demo-java-goof") | .proxy_listen_port' $PGPATH/config.yaml)"
DEMO_WEBAPP_LISTEN_PORT="$(yq '.services[] | select(.name=="demo-webapp") | .proxy_listen_port' $PGPATH/config.yaml)"
ATTACKERS_NAMESPACE="$(yq '.services[] | select(.name=="demo-attack") | .namespace' $PGPATH/config.yaml)"

mkdir -p $PGPATH/overrides

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
  printf '%s' "Create attacker and victims namespaces"
  NAMESPACE=${VICTIMS_NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  NAMESPACE=${ATTACKERS_NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Deploys Java Goof to
# Kubernetes
# Globals:
#   VICTIMS_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_java_goof() {
  # API_KEY_ADMISSION_CONTROLLER=${API_KEY_ADMISSION_CONTROLLER} \
  #   REGION=${REGION} \
  #   INSTANCE=${INSTANCE} \
  #   DEPLOY_RT=${DEPLOY_RT} \
  #   envsubst <$PGPATH/templates/container-security-overrides.yaml >$PGPATH/overrides/container-security-overrides.yaml

  printf '%s\n' "(Re-)deploy vulnerable applications"
  NAMESPACE=${VICTIMS_NAMESPACE} \
    envsubst <$PGPATH/templates/demo-java-goof.yaml >$PGPATH/overrides/demo-java-goof.yaml
  kubectl apply -f $PGPATH/overrides/demo-java-goof.yaml
 
  until kubectl get svc -n ${VICTIMS_NAMESPACE} java-goof-service --output=jsonpath='{.status.loadBalancer}' | grep "ingress"; do : ; done
  if is_eks ; then
    JAVAGOOFURL=$(kubectl get svc -n ${VICTIMS_NAMESPACE} --selector=app=java-goof -o jsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}')
  else
    JAVAGOOFURL=$(kubectl get svc -n ${VICTIMS_NAMESPACE} --selector=app=java-goof -o jsonpath='{.items[*].status.loadBalancer.ingress[0].ip}')
  fi
  echo "💬 java-goof URL: http://${JAVAGOOFURL}"
}

#######################################
# Deploys openssl3 based vulnerable app
# to Kubernetes
# Globals:
#   VICTIMS_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_openssl3() {

  NAMESPACE=${VICTIMS_NAMESPACE} \
    envsubst <$PGPATH/templates/demo-openssl3.yaml >$PGPATH/overrides/demo-openssl3.yaml
  kubectl apply -f $PGPATH/overrides/demo-openssl3.yaml

  until kubectl get -n ${VICTIMS_NAMESPACE} svc web-app-service --output=jsonpath='{.status.loadBalancer}' | grep "ingress"; do : ; done
  if is_eks ; then
    WEBAPPURL=$(kubectl get svc -n ${VICTIMS_NAMESPACE} --selector=app=web-app -o jsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}')
  else
    WEBAPPURL=$(kubectl get svc -n ${VICTIMS_NAMESPACE} --selector=app=web-app -o jsonpath='{.items[*].status.loadBalancer.ingress[0].ip}')
  fi
  echo "💬 web-app URL: http://${WEBAPPURL}"
  echo "💬 Vulnerable apps deployed."
}

#######################################
# Deploys a privileged pod in HostPID
# namespace
# to Kubernetes
# Globals:
#   VICTIMS_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_privileged() {

  kubectl -n ${ATTACKERS_NAMESPACE} run privileged-$(openssl rand -hex 4) --image mawinkler/kod:latest \
  --overrides \
    '
    {
      "metadata":{
        "labels":{
          "app": "shell"
      }},
      "spec":{
        "hostPID": true,
        "hostNetwork": true,
        "containers":[{
          "name":"kod",
          "image": "mawinkler/kod:latest",
          "volumeMounts":[{"mountPath": "/kubernetes", "name": "host-mount"}],
          "imagePullPolicy": "Always",
          "stdin": true,
          "tty": true,
          "command":["/bin/bash"],
          "nodeSelector":{
            "dedicated":"master"
          },
          "securityContext":{
            "privileged":true
          }
        }],
        "volumes":[{
          "name": "host-mount",
          "hostPath": {"path": "/etc/kubernetes"}
        }]
      } 
    }
    '
  echo "💬 Privileged pod deployed."
}

#######################################
# Deploys attackers
# Globals:
#   ATTACKERS_NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_attackers() {

  kubectl delete ns ${ATTACKERS_NAMESPACE}
  NAMESPACE=${ATTACKERS_NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  kubectl -n ${ATTACKERS_NAMESPACE} -l app=attacker-cve-2017-5638 run attacker-cve-2017-5638 --image mawinkler/c1-cs-attacker-cve-2017-5638
  echo "💬 Attackers deployed."
}

#######################################
# Main:
# Implements the attack demo
# environment
#######################################
function main() {

  create_namespace
  deploy_java_goof
  deploy_openssl3
  deploy_attackers
  deploy_privileged

  # test if we're using a managed kubernetes cluster on GCP, Azure (or AWS)
  if is_gke || is_aks || is_eks ; then
    echo "Demo Java-Goof: http://${JAVAGOOFURL}" | tee -a $PGPATH/services
    echo "Demo WebApp: http://${WEBAPPURL}" | tee -a $PGPATH/services
    echo "Check Vulnerability View for CVE-2017-5638" | tee -a $PGPATH/services
    echo | tee -a $PGPATH/services
  else
    $PGPATH/bin/deploy-proxy.sh demo-java-goof
    $PGPATH/bin/deploy-proxy.sh demo-webapp
    echo "Demo Java-Goof: $(hostname -I | awk '{print $1}'):${DEMO_JAVA_GOOF_LISTEN_PORT}" | tee -a $PGPATH/services
    echo "Demo WebApp: $(hostname -I | awk '{print $1}'):${DEMO_WEBAPP_LISTEN_PORT}" | tee -a $PGPATH/services
    echo "Check Vulnerability View for CVE-2017-5638" | tee -a $PGPATH/services
    echo | tee -a $PGPATH/services
  fi
}

function cleanup() {
  kubectl delete namespace ${VICTIMS_NAMESPACE}
  kubectl delete namespace ${ATTACKERS_NAMESPACE}
}

function test() {
  return
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi

printf '\n%s\n' "###TASK-COMPLETED###"
