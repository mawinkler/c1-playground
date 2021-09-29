#!/bin/bash

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"

echo Deleting Cluster ${CLUSTER_NAME}
kind delete clusters ${CLUSTER_NAME}
# docker stop ${CLUSTER_NAME}-control-plane
# docker rm ${CLUSTER_NAME}-control-plane

sudo rm -Rf auth certs overrides audit/audit-webhook.yaml /tmp/passthrough.conf log/* services opa
