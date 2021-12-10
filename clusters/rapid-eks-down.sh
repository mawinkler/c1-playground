#!/bin/bash

# Exports
export AWS_REGION=eu-central-1

set -e

EXISTING_NAMESPACES=$(kubectl get ns -o json | jq -r '.items[].metadata.name' | tr '\n' '|')

for NAMESPACE in $(cat config.json | jq -r '.services[].namespace'); do
  if [ "$NAMESPACE" != "null" ] && [[ ! "$NAMESPACE" =~ "kube-system"|"kube-public"|"kube-node-lease" ]]; then
    if [[ $EXISTING_NAMESPACES == *"$NAMESPACE"* ]]; then
      kubectl delete namespace ${NAMESPACE}
    fi
  fi
done

eksctl delete cluster --name $(jq -r '.cluster_name' config.json)
#`eksctl get cluster -o json | jq -r '.[].metadata.name' | grep playground`

# # Delete Keys
# aws ec2 delete-key-pair --key-name ${KEY_NAME}
# aws kms delete-alias --alias-name ${KEY_ALIAS_NAME}
