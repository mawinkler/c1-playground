#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(jq -r '.services[] | select(.name=="gatekeeper") | .namespace' $PGPATH/config.json)"

helm --namespace ${NAMESPACE} delete gatekeeper

kubectl delete namespace ${NAMESPACE}
