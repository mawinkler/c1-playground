#!/bin/bash

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"

echo Deleting Cluster ${CLUSTER_NAME}
kind delete clusters ${CLUSTER_NAME}

sudo rm -Rf auth certs overrides audit/audit-webhook.yaml /tmp/passthrough.conf log/* services opa
