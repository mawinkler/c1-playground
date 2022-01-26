#!/bin/bash

#######################################
# Main:
# Deploys AKS Cluster
#######################################
function main() {
  # Exports
  export APP_NAME="$(jq -r '.cluster_name' config.json)"
  export CLUSTER_NAME=${APP_NAME}

  az group create --name ${APP_NAME} --location westeurope
  az aks create \
    --resource-group ${APP_NAME} \
    --name ${CLUSTER_NAME} \
    --node-count 2 \
    --enable-addons monitoring \
    --generate-ssh-keys
  az aks get-credentials --resource-group ${APP_NAME} --name ${CLUSTER_NAME}

  echo "Creating rapid-aks-down.sh script"
  cat <<EOF >rapid-aks-down.sh
#!/bin/bash
export APP_NAME="$(jq -r '.cluster_name' config.json)"
az group delete --name ${APP_NAME} -y
sudo rm -Rf auth certs overrides audit/audit-webhook.yaml /tmp/passthrough.conf log/* services opa
EOF
  chmod +x rapid-aks-down.sh
  echo "Run rapid-aks-down.sh to tear down everything"
}

function cleanup() {
  ./rapid-aks-down.sh
  if [ $? -eq 0 ] ; then
    return
  fi
  false
}

function test() {
  for i in {1..60} ; do
    sleep 5
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -A | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -A | grep -E "([0-9]+)/\1" | wc -l)
    if [ $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ] ; then
        echo ${DEPLOYMENTS_READY}
        return
    fi
  done
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi