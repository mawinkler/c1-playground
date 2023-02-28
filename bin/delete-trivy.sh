#!/bin/bash
# set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE_TRIVY="$(jq -r '.services[] | select(.name=="trivy") | .namespace' $PGPATH/config.json)"

helm --namespace ${NAMESPACE_TRIVY} delete trivy-operator

kubectl delete namespace ${NAMESPACE_TRIVY}

printf '\n%s\n' "###TASK-COMPLETED###"
