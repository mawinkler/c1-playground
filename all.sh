#!/bin/bash
set -o errexit

./up.sh
./deploy-starboard.sh
./deploy-falco.sh
./deploy-prometheus-grafana.sh
./deploy-smartcheck.sh
./deploy-container-security.sh
