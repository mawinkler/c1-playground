#!/bin/bash

set -e

EXISTING_NAMESPACES=$(kubectl get ns -o json | jq -r '.items[].metadata.name' | tr '\n' '|')"kube-system"

for NAMESPACE in $(cat config.yaml | yq '.services[].namespace'); do
  if [ "$NAMESPACE" != "null" ]; then
    if [[ "$NAMESPACE" =~ ^($EXISTING_NAMESPACES) ]]; then
      kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=true
      kubectl label namespace ${NAMESPACE} --overwrite network=green
      kubectl label namespace ${NAMESPACE} --overwrite openpolicyagent.org/webhook=ignore
    fi
  fi
done
