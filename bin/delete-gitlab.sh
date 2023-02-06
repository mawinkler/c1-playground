#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

GITLAB_CONTAINER_NAME="$(jq -r '.services[] | select(.name=="gitlab") | .container_name' $PGPATH/config.json)"
GITLAB_RUNNER_CONTAINER_NAME="$(jq -r '.services[] | select(.name=="gitlab") | .dind_name' $PGPATH/config.json)"

docker stop ${GITLAB_RUNNER_CONTAINER_NAME}
docker rm ${GITLAB_RUNNER_CONTAINER_NAME}
docker stop ${GITLAB_CONTAINER_NAME}
docker rm ${GITLAB_CONTAINER_NAME}
