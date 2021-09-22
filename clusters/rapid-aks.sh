#!/bin/bash

# Exports
export APP_NAME=playground
export CLUSTER_NAME=aks-playground

az group create --name ${APP_NAME} --location westeurope
az aks create \
    --resource-group ${APP_NAME} \
    --name ${CLUSTER_NAME} \
    --node-count 2 \
    --enable-addons monitoring \
    --generate-ssh-keys
az aks get-credentials --resource-group ${APP_NAME} --name ${CLUSTER_NAME}

echo "Done."

echo "Delete project run: az group delete -y --name ${APP_NAME}"
