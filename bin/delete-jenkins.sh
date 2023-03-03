#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

JENKINS_DIND_CONTAINER_NAME="$(yq '.services[] | select(.name=="jenkins") | .dind_name' $PGPATH/config.yaml)"
JENKINS_CONTAINER_NAME="$(yq '.services[] | select(.name=="jenkins") | .container_name' $PGPATH/config.yaml)"
JENKINS_VOLUME_DATA="$(yq '.services[] | select(.name=="jenkins") | .volume_data' $PGPATH/config.yaml)"
JENKINS_VOLUME_DOCKER_CERTS="$(yq '.services[] | select(.name=="jenkins") | .volume_docker_certs' $PGPATH/config.yaml)"

docker stop ${JENKINS_DIND_CONTAINER_NAME}
docker stop ${JENKINS_CONTAINER_NAME}
docker rm ${JENKINS_CONTAINER_NAME}
docker volume rm ${JENKINS_VOLUME_DATA}
docker volume rm ${JENKINS_VOLUME_DOCKER_CERTS}

printf '\n%s\n' "###TASK-COMPLETED###"
