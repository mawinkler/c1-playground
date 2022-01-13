#!/bin/bash
set -o errexit

./up.sh
./deploy-registry.sh
./deploy-falco.sh
./deploy-prometheus-grafana.sh
#./deploy-smartcheck.sh
#./deploy-container-security.sh
./deploy-starboard.sh
./whitelist_playground_ns.sh
