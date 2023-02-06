#!/bin/bash

set -e

# Source helpers
.  ${PGPATH}/bin/playground-helpers.sh

# Get config
JENKINS_HOSTNAME="$(jq -r '.services[] | select(.name=="jenkins") | .hostname' ${PGPATH}/config.json)"

JENKINS_DIND_CONTAINER_NAME="$(jq -r '.services[] | select(.name=="jenkins") | .dind_name' ${PGPATH}/config.json)"
JENKINS_CONTAINER_NAME="$(jq -r '.services[] | select(.name=="jenkins") | .container_name' ${PGPATH}/config.json)"
JENKINS_DIND_PORT="$(jq -r '.services[] | select(.name=="jenkins") | .dind_port' ${PGPATH}/config.json)"
JENKINS_AGENT_PORT="$(jq -r '.services[] | select(.name=="jenkins") | .agent_port' ${PGPATH}/config.json)"
JENKINS_SERVICE_PORT="$(jq -r '.services[] | select(.name=="jenkins") | .service_port' ${PGPATH}/config.json)"
JENKINS_VOLUME_DATA="$(jq -r '.services[] | select(.name=="jenkins") | .volume_data' ${PGPATH}/config.json)"
JENKINS_VOLUME_DOCKER_CERTS="$(jq -r '.services[] | select(.name=="jenkins") | .volume_docker_certs' ${PGPATH}/config.json)"

REGISTRY_HOST=$(hostname -I | awk '{print $1}')
REGISTRY_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .proxy_listen_port' ${PGPATH}/config.json)"

#######################################
# Creates the Jenkins Docker Network
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function ensure_network() {
  printf '%s' "Create jenkins namespace"
  NETWORKS=$(docker network ls --filter 'name=jenkins' --quiet)
  if [ "$NETWORKS" == "" ]; then
    printf '%s' "creating network jenkins"
    docker network create jenkins
  else
    printf '%s' "network jenkins already exists"
  fi
  printf '%s\n' " 🍼"
}

#######################################
# Creates a Jenkins Worker image based
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
function create_dind_container_image() {
  printf '%s\n' "create jenkins image"
  REGISTRY=${REGISTRY_HOST}:${REGISTRY_PORT}

  cp ${PGPATH}/certs/tls.crt ${PGPATH}/certs/${REGISTRY}.crt
  REGISTRY=${REGISTRY} envsubst <${PGPATH}/templates/jenkins-dockerfile-runner >${PGPATH}/overrides/jenkins-dockerfile-runner

  docker build -t ${JENKINS_DIND_CONTAINER_NAME} -f ${PGPATH}/overrides/jenkins-dockerfile-runner ${PGPATH}/certs/.

  printf '%s\n' "jenkins image created 🍻"
}

#######################################
# Ensures that the Jenkins Worker
# Container is running
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function ensure_dind_container() {
  CONTAINERS=$(docker ps --filter "name=${JENKINS_DIND_CONTAINER_NAME}" --quiet)
  if [ "$CONTAINERS" == "" ]; then
    printf '%s' "creating dind container"
    docker run --name ${JENKINS_DIND_CONTAINER_NAME} \
      --rm --detach --privileged \
      --network jenkins --network-alias docker \
      --env DOCKER_TLS_CERTDIR=/certs \
      --volume ${JENKINS_VOLUME_DOCKER_CERTS}:/certs/client \
      --volume ${JENKINS_VOLUME_DATA}:/var/jenkins_home \
      --publish ${JENKINS_DIND_PORT}:2376 \
      ${JENKINS_DIND_CONTAINER_NAME} \
      --storage-driver overlay2
  else
    printf '%s' "dind container already exists"
  fi
  printf '%s\n' " 🍼"
}

#######################################
# Create the Jenkins container image
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function create_jenkins_image() {
  printf '%s\n' "create jenkins image"

  docker build -t ${JENKINS_CONTAINER_NAME}:2.375.1-1 - < ${PGPATH}/templates/jenkins-dockerfile

  printf '%s\n' "jenkins image created 🍻"
}

#######################################
# Ensures that the Jenkins
# Container is running
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#######################################
function ensure_jenkins_container() {
  printf '%s\n' "create jenkins image"
  CONTAINERS=$(docker ps --filter "name=${JENKINS_CONTAINER_NAME}" --quiet)
  if [ "$CONTAINERS" == "" ]; then
    printf '%s' "creating jenkins container "
    docker run --name ${JENKINS_CONTAINER_NAME} \
      --restart=on-failure \
      --detach \
      --network jenkins \
      --env DOCKER_HOST=tcp://docker:${JENKINS_DIND_PORT} \
      --env DOCKER_CERT_PATH=/certs/client \
      --env DOCKER_TLS_VERIFY=1 \
      --publish ${JENKINS_SERVICE_PORT}:8080 \
      --publish ${JENKINS_AGENT_PORT}:50000 \
      --volume ${JENKINS_VOLUME_DATA}:/var/jenkins_home \
      --volume ${JENKINS_VOLUME_DOCKER_CERTS}:/certs/client:ro \
      ${JENKINS_CONTAINER_NAME}:2.375.1-1
  else
    printf '%s' "jenkins container already exists"
  fi
}

#######################################
# Retrieves the initial Jenkins admin
# password. If an already initialized
# Jenkins volume does exist, this
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
    ADMIN_PASSWORD=$(docker exec ${JENKINS_CONTAINER_NAME} sh -c 'if [ -f /var/jenkins_home/secrets/initialAdminPassword ]; then cat /var/jenkins_home/secrets/initialAdminPassword; else echo ""; fi')
    if [ "${ADMIN_PASSWORD}" != "" ] ; then
      break
    fi
    printf '%s' "."
  done
  printf '\n'
}

ensure_network
create_dind_container_image
ensure_dind_container
create_jenkins_image
ensure_jenkins_container
get_initial_admin_password

echo "Jenkins: http://$(hostname -I | awk '{print $1}'):${JENKINS_SERVICE_PORT}" | tee -a ${PGPATH}/services
echo "  U/P: admin / ${ADMIN_PASSWORD}" | tee -a ${PGPATH}/services
echo | tee -a ${PGPATH}/services