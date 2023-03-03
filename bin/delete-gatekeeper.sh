#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(yq '.services[] | select(.name=="gatekeeper") | .namespace' $PGPATH/config.yaml)"

helm --namespace ${NAMESPACE} delete gatekeeper

kubectl delete namespace ${NAMESPACE}

printf '\n%s\n' "###TASK-COMPLETED###"
