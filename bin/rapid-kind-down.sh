#!/bin/bash
set -o errexit

CLUSTER_NAME="$(yq '.cluster_name' $PGPATH/config.yaml | tr '[:upper:]' '[:lower:]')"

echo Deleting Cluster ${CLUSTER_NAME}
kind delete clusters ${CLUSTER_NAME}

sudo rm -Rf $PGPATH/auth $PGPATH/certs $PGPATH/audit/audit-webhook.yaml /tmp/passthrough.conf $PGPATH/services $PGPATH/opa
# $PGPATH/log/*
printf '\n%s\n' "###TASK-COMPLETED###"
