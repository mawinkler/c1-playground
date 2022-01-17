#!/bin/bash

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
EOF
chmod +x rapid-aks-down.sh
echo "Run rapid-aks-down.sh to tear down everything"
