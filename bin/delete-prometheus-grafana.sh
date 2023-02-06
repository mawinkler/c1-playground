#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(jq -r '.services[] | select(.name=="prometheus") | .namespace' $PGPATH/config.json)"

helm --namespace ${NAMESPACE} delete prometheus \

kubectl delete namespace ${NAMESPACE}
