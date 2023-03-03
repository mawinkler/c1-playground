#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(yq '.services[] | select(.name=="harbor") | .namespace' $PGPATH/config.yaml)"

helm -n ${NAMESPACE} delete harbor

kubectl delete namespace ${NAMESPACE}

printf '\n%s\n' "###TASK-COMPLETED###"
