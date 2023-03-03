#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(yq '.services[] | select(.name=="opa") | .namespace' $PGPATH/config.yaml)"

kubectl delete -f $PGPATH/opa/admission-controller.yaml
kubectl delete -f $PGPATH/opa/webhook-configuration.yaml

kubectl delete namespace ${NAMESPACE}

printf '\n%s\n' "###TASK-COMPLETED###"
