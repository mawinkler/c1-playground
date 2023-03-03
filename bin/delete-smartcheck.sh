#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

SC_NAMESPACE="$(yq '.services[] | select(.name=="smartcheck") | .namespace' $PGPATH/config.yaml)"

helm delete \
    smartcheck \
    --namespace ${SC_NAMESPACE}

kubectl delete namespace ${SC_NAMESPACE}

printf '\n%s\n' "###TASK-COMPLETED###"
