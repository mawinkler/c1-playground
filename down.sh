#!/bin/bash

# REGISTRY_NAME="$(jq -r '.host_registry_name' config.json)"

kind delete clusters playground
# docker stop ${REGISTRY_NAME}
# docker rm ${REGISTRY_NAME}

sudo rm -Rf auth certs overrides audit/audit-webhook.yaml /tmp/passthrough.conf log/* services
