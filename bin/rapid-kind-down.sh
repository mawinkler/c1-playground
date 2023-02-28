#!/bin/bash
set -o errexit

CLUSTER_NAME="$(jq -r '.cluster_name' $PGPATH/config.json)"

echo Deleting Cluster ${CLUSTER_NAME}
kind delete clusters ${CLUSTER_NAME}

sudo rm -Rf $PGPATH/auth $PGPATH/certs $PGPATH/audit/audit-webhook.yaml /tmp/passthrough.conf $PGPATH/services $PGPATH/opa
# $PGPATH/log/*
printf '\n%s\n' "###TASK-COMPLETED###"
