#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(yq '.services[] | select(.name=="prometheus") | .namespace' $PGPATH/config.yaml)"

helm --namespace ${NAMESPACE} delete prometheus \

kubectl delete namespace ${NAMESPACE}

printf '\n%s\n' "###TASK-COMPLETED###"
