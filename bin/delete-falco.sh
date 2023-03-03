#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(yq '.services[] | select(.name=="falco") | .namespace' $PGPATH/config.yaml)"

helm -n ${NAMESPACE} delete falco
helm -n ${NAMESPACE} delete falco-exporter

kubectl delete namespace ${NAMESPACE}

printf '\n%s\n' "###TASK-COMPLETED###"
