#!/bin/bash

# Exports
export APP_NAME="$(jq -r '.cluster_name' config.json)"
az group delete --name ${APP_NAME} -y