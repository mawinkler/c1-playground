#!/bin/bash
set -o errexit

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

GITLAB_CONTAINER_NAME="$(yq '.services[] | select(.name=="gitlab") | .container_name' $PGPATH/config.yaml)"
GITLAB_RUNNER_CONTAINER_NAME="$(yq '.services[] | select(.name=="gitlab") | .container_runner_name' $PGPATH/config.yaml)"

docker stop ${GITLAB_RUNNER_CONTAINER_NAME}
docker rm ${GITLAB_RUNNER_CONTAINER_NAME}
docker stop ${GITLAB_CONTAINER_NAME}
docker rm ${GITLAB_CONTAINER_NAME}

printf '\n%s\n' "###TASK-COMPLETED###"
