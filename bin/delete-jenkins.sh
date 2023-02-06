#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

JENKINS_DIND_CONTAINER_NAME="$(jq -r '.services[] | select(.name=="jenkins") | .dind_name' $PGPATH/config.json)"
JENKINS_CONTAINER_NAME="$(jq -r '.services[] | select(.name=="jenkins") | .container_name' $PGPATH/config.json)"
JENKINS_VOLUME_DATA="$(jq -r '.services[] | select(.name=="jenkins") | .volume_data' $PGPATH/config.json)"
JENKINS_VOLUME_DOCKER_CERTS="$(jq -r '.services[] | select(.name=="jenkins") | .volume_docker_certs' $PGPATH/config.json)"

docker stop ${JENKINS_DIND_CONTAINER_NAME}
docker stop ${JENKINS_CONTAINER_NAME}
docker rm ${JENKINS_CONTAINER_NAME}
docker volume rm ${JENKINS_VOLUME_DATA}
docker volume rm ${JENKINS_VOLUME_DOCKER_CERTS}
