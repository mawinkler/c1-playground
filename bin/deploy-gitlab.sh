#!/bin/bash

# set -e

# Source helpers
.  ${PGPATH}/bin/playground-helpers.sh

# Get config
GITLAB_HOSTNAME="$(jq -r '.services[] | select(.name=="gitlab") | .hostname' ${PGPATH}/config.json)"

GITLAB_HOME_GITLAB="$(jq -r '.services[] | select(.name=="gitlab") | .home_gitlab' ${PGPATH}/config.json)"
GITLAB_HOME_GITLAB_RUNNER="$(jq -r '.services[] | select(.name=="gitlab") | .home_gitlab_runner' ${PGPATH}/config.json)"
GITLAB_CONTAINER_NAME="$(jq -r '.services[] | select(.name=="gitlab") | .container_name' ${PGPATH}/config.json)"
GITLAB_RUNNER_CONTAINER_NAME="$(jq -r '.services[] | select(.name=="gitlab") | .container_runner_name' ${PGPATH}/config.json)"
GITLAB_HTTP_PORT="$(jq -r '.services[] | select(.name=="gitlab") | .gitlab_http_port' ${PGPATH}/config.json)"
GITLAB_HTTPS_PORT="$(jq -r '.services[] | select(.name=="gitlab") | .gitlab_https_port' ${PGPATH}/config.json)"
GITLAB_SSH_PORT="$(jq -r '.services[] | select(.name=="gitlab") | .gitlab_ssh_port' ${PGPATH}/config.json)"
GITLAB_SERVICE_PORT="$(jq -r '.services[] | select(.name=="gitlab") | .service_port' ${PGPATH}/config.json)"

REGISTRY_HOST=$(hostname -I | awk '{print $1}')
REGISTRY_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .proxy_listen_port' ${PGPATH}/config.json)"
EXTERNAL_IP=$(hostname -I | awk '{print $1}')

#######################################
# Creates the GitLab Docker Network
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
# function ensure_network() {
#   printf '%s' "Create gitlab namespace"
#   NETWORKS=$(docker network ls --filter 'name=gitlab' --quiet)
#   if [ "$NETWORKS" == "" ]; then
#     printf '%s' "creating network gitlab"
#     docker network create gitlab
#   else
#     printf '%s' "network gitlab already exists"
#   fi
#   printf '%s\n' " 🍼"
# }

#######################################
# Creates a GitLab Worker image based
# on docker:dind, but with the ssl
# certificate from the k8s resgistry
# included in the trust store
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
# function create_dind_container_image() {
#   printf '%s\n' "create gitlab image"
#   REGISTRY=${REGISTRY_HOST}:${REGISTRY_PORT}

#   cp ${PGPATH}/certs/tls.crt ${PGPATH}/certs/${REGISTRY}.crt
#   REGISTRY=${REGISTRY} envsubst <${PGPATH}/templates/gitlab-dockerfile-runner >${PGPATH}/overrides/gitlab-dockerfile-runner

#   docker build -t ${GITLAB_RUNNER_CONTAINER_NAME} -f ${PGPATH}/overrides/gitlab-dockerfile-runner ${PGPATH}/certs/.

#   printf '%s\n' "gitlab image created 🍻"
# }

#######################################
# Ensures that the GitLab Worker
# Container is running
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function ensure_runner_container() {
  CONTAINERS=$(docker ps --filter "name=${GITLAB_RUNNER_CONTAINER_NAME}" --quiet)
  if [ "$CONTAINERS" == "" ]; then
    printf '%s' "Creating runner container "

    docker run --name ${GITLAB_RUNNER_CONTAINER_NAME} \
      --detach \
      --privileged \
      --restart always \
      --volume /var/run/docker.sock:/var/run/docker.sock \
      --volume ${GITLAB_HOME_GITLAB_RUNNER}/config:/etc/gitlab-runner \
      gitlab/gitlab-runner:latest

      # -v ${GITLAB_RUNNER_CONFIG}/srv/gitlab-runner:/etc/gitlab-runner \
      # --network-alias docker \
      # --network gitlab \
  else
    printf '%s\n' "Runner container already exists"
  fi
  # printf '%s\n' " 🍼"
}

#######################################
# Create the GitLab container image
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
# function create_gitlab_image() {
#   printf '%s\n' "Create gitlab image"

#   docker build -t ${GITLAB_CONTAINER_NAME}:2.375.1-1 - < ${PGPATH}/templates/gitlab-dockerfile

#   printf '%s\n' "Gitlab image created 🍻"
# }

#######################################
# Ensures that the GitLab
# Container is running
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function ensure_gitlab_container() {
  CONTAINERS=$(docker ps --filter "name=${GITLAB_CONTAINER_NAME}" --quiet)
  if [ "$CONTAINERS" == "" ]; then
    printf '%s' "Creating gitlab container "
    docker run \
      --detach \
      --hostname gitlab.example.com \
      --restart always \
      --env GITLAB_OMNIBUS_CONFIG="external_url 'http://${EXTERNAL_IP}/'; gitlab_rails['lfs_enabled'] = true;" \
      --publish ${GITLAB_HTTPS_PORT}:443 \
      --publish ${GITLAB_HTTP_PORT}:80 \
      --publish ${GITLAB_SSH_PORT}:22 \
      --name ${GITLAB_CONTAINER_NAME} \
      --volume ${GITLAB_HOME_GITLAB}/config:/etc/gitlab \
      --volume ${GITLAB_HOME_GITLAB}/logs:/var/log/gitlab \
      --volume ${GITLAB_HOME_GITLAB}/data:/var/opt/gitlab \
      --shm-size 256m \
      gitlab/gitlab-ce:latest

      # --network gitlab \

    # docker run --name ${GITLAB_CONTAINER_NAME} \
    #   --restart=on-failure \
    #   --detach \
    #   --network gitlab \
    #   --env DOCKER_HOST=tcp://docker:${GITLAB_DIND_PORT} \
    #   --env DOCKER_CERT_PATH=/certs/client \
    #   --env DOCKER_TLS_VERIFY=1 \
    #   --publish ${GITLAB_SERVICE_PORT}:8080 \
    #   --publish ${GITLAB_AGENT_PORT}:50000 \
    #   --volume ${GITLAB_VOLUME_DATA}:/var/gitlab_home \
    #   --volume ${GITLAB_VOLUME_DOCKER_CERTS}:/certs/client:ro \
    #   ${GITLAB_CONTAINER_NAME}:2.375.1-1
  else
    printf '%s\n' "gitlab container already exists"
  fi
}

#######################################
# Retrieves the initial GitLab admin
# password. If an already initialized
# GitLab volume does exist, this
# function will silently timeout.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function get_initial_admin_password() {
  printf '%s' "Waiting for admin password"
  for i in {1..60} ; do
    sleep 2
    ADMIN_PASSWORD=$(docker exec gitlab-ce sh -c 'if [ -f /etc/gitlab/initial_root_password ]; then cat /etc/gitlab/initial_root_password; else echo ""; fi' | sed -rn 's/^Password\:\s(.*).*/\1/p')
    if [ "${ADMIN_PASSWORD}" != "" ] ; then
      break
    fi
    printf '%s' "."
  done
  printf '\n'
}

function get_runner_registration_token() {
  printf '%s' "Retrieve runner registration token"
  for i in {1..30} ; do
    sleep 5
    REGISTRATION_TOKEN=$(docker exec -it gitlab-ce /bin/sh -c 'gitlab-rails runner "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"')
    # Test if we got an error or a string with a length of less than 24 characters. Registration tokens
    # have a length of 21 characters
    if [ "${REGISTRATION_TOKEN}" != "" ] && [ "$(echo ${REGISTRATION_TOKEN} | wc -c)" -lt "24" ]; then
      break
    fi
    printf '%s' "."
  done
  printf '\n'
}

function register_runner() {
  printf '%s\n' "Register runner"
  sleep 30
  for i in {1..300} ; do
    sleep 5
    MESSAGE=$(docker run --rm -it \
      -v /srv/gitlab-runner/config:/etc/gitlab-runner \
      gitlab/gitlab-runner:latest register \
      --non-interactive \
      --url "http://${EXTERNAL_IP}:${GITLAB_HTTP_PORT}/" \
      --registration-token "${REGISTRATION_TOKEN}" \
      --executor "docker" \
      --docker-image ubuntu:latest \
      --description "docker-runner" \
      --tag-list "docker" \
      --run-untagged="true" \
      --locked="false" \
      --access-level="not_protected" \
      --docker-privileged \
      --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
      --docker-volumes "/cache")
    if [ "$(echo ${MESSAGE} | grep 'Runner registered successfully')" != "" ]; then
      break
    fi
    printf '%s' "."
  done
  printf '\n'
}

# ensure_network
# create_dind_container_image
ensure_runner_container
# create_gitlab_image
ensure_gitlab_container
get_initial_admin_password
get_runner_registration_token
register_runner

echo "GitLab: http://$(hostname -I | awk '{print $1}'):${GITLAB_SERVICE_PORT}" | tee -a ${PGPATH}/services
echo "  U/P: root / ${ADMIN_PASSWORD}" | tee -a ${PGPATH}/services
echo "  Runner Registrytion Token: ${REGISTRATION_TOKEN}" | tee -a ${PGPATH}/services
echo | tee -a ${PGPATH}/services