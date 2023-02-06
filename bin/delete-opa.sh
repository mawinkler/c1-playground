#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

NAMESPACE="$(jq -r '.services[] | select(.name=="opa") | .namespace' $PGPATH/config.json)"

kubectl delete -f $PGPATH/opa/admission-controller.yaml
kubectl delete -f $PGPATH/opa/webhook-configuration.yaml

kubectl delete namespace ${NAMESPACE}
