#!/bin/bash
# set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE_TRIVY="$(jq -r '.services[] | select(.name=="trivy") | .namespace' $PGPATH/config.json)"
NAMESPACE_STARBOARD="$(jq -r '.services[] | select(.name=="starboard") | .namespace' $PGPATH/config.json)"

helm --namespace ${NAMESPACE_TRIVY} delete trivy-operator
helm --namespace ${NAMESPACE_STARBOARD} delete starboard-operator

kubectl delete namespace ${NAMESPACE_TRIVY}
kubectl delete namespace ${NAMESPACE_STARBOARD}
