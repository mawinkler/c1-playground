#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' $PGPATH/config.json)"

helm delete \
    smartcheck \
    --namespace ${SC_NAMESPACE}

kubectl delete namespace ${SC_NAMESPACE}
