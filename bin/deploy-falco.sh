#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
NAMESPACE="$(yq '.services[] | select(.name=="falco") | .namespace' $PGPATH/config.yaml)"
HOSTNAME="$(yq '.services[] | select(.name=="falco") | .hostname' $PGPATH/config.yaml)"
SERVICE_NAME="$(yq '.services[] | select(.name=="falco") | .proxy_service_name' $PGPATH/config.yaml)"
LISTEN_PORT="$(yq '.services[] | select(.name=="falco") | .proxy_listen_port' $PGPATH/config.yaml)"

#######################################
# Creates Kubernetes namespace
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_namespace() {
  # create namespace
  printf '%s' "Create falco namespace"
  NAMESPACE=${NAMESPACE} envsubst <$PGPATH/templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

#######################################
# Whitelists Kubernetes namespace for
# Falco
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function whitelist_namsspace() {
  # whitelist some namespace for container security
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=true
}

#######################################
# Deploys Falco to Kubernetes
# Globals:
#   NAMESPACE
# Arguments:
#   None
# Outputs:
#   None
#######################################
function deploy_falco() {
  ## deploy falco
  printf '%s\n' "deploy falco"

  helm repo add falcosecurity https://falcosecurity.github.io/charts
  helm repo update

  mkdir -p $PGPATH/overrides
  envsubst <$PGPATH/templates/falco-overrides.yaml >$PGPATH/overrides/falco-overrides.yaml

  # If running on GKE or AKS we switch to eBPF
  if is_gke || is_aks || is_eks || is_kind ; then
    echo "ebpf:" >> $PGPATH/overrides/falco-overrides.yaml
    echo "  enabled: true" >> $PGPATH/overrides/falco-overrides.yaml
  fi

  echo "customRules:" > $PGPATH/overrides/falco-custom-rules.yaml

  # If there is a file called `falco/playground_rules_dev.yaml`, we append it to the falco-custom-rules.yaml
  # and skip the playground and additional rule files
  if [ -f "falco/playground_rules_dev.yaml" ]; then
    printf '%s\n' "Playground Dev rules file found"
    echo "  a_playground_rules_dev.yaml: |-" >> $PGPATH/overrides/falco-custom-rules.yaml
    cat falco/playground_rules_dev.yaml | sed  -e 's/^/    /' >> $PGPATH/overrides/falco-custom-rules.yaml
  else    
    # If there is a file called `falco/playground_rules.yaml`, we append it to the falco-custom-rules.yaml
    if [ -f "falco/playground_rules.yaml" ]; then
      printf '%s\n' "Playground rules file found"
      echo "  a_playground_rules.yaml: |-" >> $PGPATH/overrides/falco-custom-rules.yaml
      cat falco/playground_rules.yaml | sed  -e 's/^/    /' >> $PGPATH/overrides/falco-custom-rules.yaml
    fi

    # If there is a file called `falco/additional_rules.yaml`, we append it to the falco-custom-rules.yaml
    if [ -f "falco/additional_rules.yaml" ]; then
      printf '%s\n' "Additional rules file found"
      echo "  z_additional_rules.yaml: |-" >> $PGPATH/overrides/falco-custom-rules.yaml
      cat falco/additional_rules.yaml | sed  -e 's/^/    /' >> $PGPATH/overrides/falco-custom-rules.yaml
    fi
  fi

  # helm delete falco && kubectl delete svc falco-np && rm /tmp/passthrough.conf && sleep 2 && $PGPATH/bin/deploy-falco.sh 

  # Install Falco
  helm -n ${NAMESPACE} upgrade \
    falco \
    --install \
    --values=$PGPATH/overrides/falco-overrides.yaml \
    -f $PGPATH/overrides/falco-custom-rules.yaml \
    falcosecurity/falco

  helm -n ${NAMESPACE} upgrade \
    falco-exporter \
    --install \
    falcosecurity/falco-exporter

  # Create NodePort Service to enable K8s Audit
  envsubst <$PGPATH/templates/falco-nodeport-service.yaml | kubectl -n ${NAMESPACE} apply -f -
}

#######################################
# Creates Kubernetes ingress
# Globals:
#   SERVICE_NAME
#   NAMESPACE
#   HOSTNAME
#   LISTEN_PORT
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_ingress() {
  printf '%s\n' "Create falco ingress"
  SERVICE_NAME=${SERVICE_NAME} \
    NAMESPACE=${NAMESPACE} \
    HOSTNAME=${HOSTNAME} \
    LISTEN_PORT=${LISTEN_PORT} \
    envsubst <$PGPATH/templates/falco-ingress.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "Falco ingress created 🍻"
}

#######################################
# Main:
# Deploys Falco
#######################################
function main() {
  create_namespace
  whitelist_namsspace
  deploy_falco

  if is_linux ; then
    # test if we're using a kind cluster and need a proxy
    if is_kind ; then
      $PGPATH/bin/deploy-proxy.sh falco
      echo "Falco UI on: http://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}/" | tee -a $PGPATH/services
      echo | tee -a $PGPATH/services
    fi
  fi
}

function cleanup() {
  helm -n ${NAMESPACE} delete \
    falco || true
  helm -n ${NAMESPACE} delete \
    falco-exporter || true
  kubectl delete namespace ${NAMESPACE} || true
  sudo rm -Rf $PGPATH/log/*
  
  for i in {1..10} ; do
    sleep 2
    if [ "$(kubectl get all -n ${NAMESPACE} | grep 'No resources found' || true)" == "" ] ; then
      return
    fi
  done
  false
}

function get_ui() {
  if is_kind ; then
    if is_linux ; then
      UI_URL="http://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}"
    else
      echo "*** Falco currently not supported on MacOS ***"
    fi
  else
    if is_eks ; then
      UI_URL="http://$(kubectl -n ${NAMESPACE} get svc falco-falcosidekick-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):${LISTEN_PORT}"
    else
      UI_URL="http://$(kubectl -n ${NAMESPACE} get svc falco-falcosidekick-ui -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):${LISTEN_PORT}"
    fi
  fi
}

function test() {
  for i in {1..20} ; do
    sleep 5
    # test deployments and pods
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -n ${NAMESPACE} | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -n ${NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    PODS_TOTAL=$(kubectl get pods -n ${NAMESPACE} | wc -l)
    PODS_READY=$(kubectl get pods -n ${NAMESPACE} | grep -E "([0-9]+)/\1" | wc -l)
    if [[ ( $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ) && ( $((${PODS_TOTAL} - 1)) -eq ${PODS_READY} ) ]] ; then
      echo ${DEPLOYMENTS_READY}
      # test web app
      get_ui
      echo ${UI_URL}
      for i in {1..10} ; do
        sleep 2
        if [ $(curl --write-out '%{http_code}' --silent --output /dev/null ${UI_URL} -eq 200) ] ; then
          return
        fi
      done
      return
    fi
  done
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi

printf '\n%s\n' "###TASK-COMPLETED###"
