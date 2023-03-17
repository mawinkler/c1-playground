#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(yq '.services[] | select(.name=="kubeclarity") | .namespace' $PGPATH/config.yaml)"

helm -n ${NAMESPACE} delete kubeclarity

kubectl delete namespace ${NAMESPACE}

printf '\n%s\n' "###TASK-COMPLETED###"
