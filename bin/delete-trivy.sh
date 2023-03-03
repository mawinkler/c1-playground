#!/bin/bash
# set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE_TRIVY="$(yq '.services[] | select(.name=="trivy") | .namespace' $PGPATH/config.yaml)"

helm --namespace ${NAMESPACE_TRIVY} delete trivy-operator

kubectl delete namespace ${NAMESPACE_TRIVY}

printf '\n%s\n' "###TASK-COMPLETED###"
