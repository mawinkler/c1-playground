#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

CS_NAMESPACE="$(jq -r '.services[] | select(.name=="container_security") | .namespace' $PGPATH/config.json)"

helm delete \
    container-security \
    --namespace ${CS_NAMESPACE}

kubectl delete namespace ${CS_NAMESPACE}

printf '\n%s\n' "###TASK-COMPLETED###"
