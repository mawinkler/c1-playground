#/bin/bash
# ##############################################################################
# Pulls an image, initiates a scan with Smart Check and creates a PDF report
# ##############################################################################

OS="$(uname)"

# Test for command line parameter
if [ -n ${1} ]; then
  TARGET_IMAGE=${1}
  TARGET_IMAGE_TAG=${2}
fi

# If no parameter was given and TARGET_IMAGE is not set in env, default to rhel7
TARGET_IMAGE=${TARGET_IMAGE:-richxsl/rhel7}
TARGET_IMAGE_TAG=${TARGET_IMAGE_TAG:-latest}

echo "Scanning Image ${TARGET_IMAGE} with tag ${TARGET_IMAGE_TAG}"

SC_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .username' config.json)"
SC_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .password' config.json)"
SC_API_PORT="$(jq -r '.services[] | select(.name=="smartcheck") | .proxy_service_port' config.json)"
REG_USERNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .username' config.json)"
REG_PASSWORD="$(jq -r '.services[] | select(.name=="playground-registry") | .password' config.json)"
REG_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' config.json)"

if [ "${OS}" == 'Linux' ]; then
  SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
  REG_NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' config.json)"
  REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
  SERVICE_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  REGISTRY_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  SC_SERVICE="${SERVICE_HOST}:${SC_API_PORT}"
fi

if [ "${OS}" == 'Darwin' ]; then
  SC_HOSTNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .hostname' config.json)"
  REGISTRY_HOST="$(jq -r '.services[] | select(.name=="playground-registry") | .hostname' config.json)"
  REG_PORT=443 # ingress
  SC_SERVICE="${SC_HOSTNAME}:${SC_API_PORT}"
fi


printf '%s\n' "Smart check is on ${SC_SERVICE}"
printf '%s\n' "Cluster registry is on ${REGISTRY_HOST}:${REG_PORT}"

echo ${REG_PASSWORD} | docker login ${REGISTRY_HOST}:${REG_PORT} --username ${REG_USERNAME} --password-stdin
docker pull ${TARGET_IMAGE}:${TARGET_IMAGE_TAG}
docker tag ${TARGET_IMAGE}:${TARGET_IMAGE_TAG} ${REGISTRY_HOST}:${REG_PORT}/${TARGET_IMAGE}:${TARGET_IMAGE_TAG}
docker push ${REGISTRY_HOST}:${REG_PORT}/${TARGET_IMAGE}:${TARGET_IMAGE_TAG}

if [ "${OS}" == 'Darwin' ]; then
  REGISTRY_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                  -o jsonpath='{.spec.clusterIP}')
  REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
  printf '%s\n' "Cluster registry is on ${REGISTRY_HOST}:${REG_PORT}"
fi

# eval docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
#   deepsecurity/smartcheck-scan-action \
#   --image-name "${REGISTRY_HOST}:${REG_PORT}/${TARGET_IMAGE}:${TARGET_IMAGE_TAG}" \
#   --smartcheck-host="$SC_SERVICE" \
#   --smartcheck-user="$SC_USERNAME" \
#   --smartcheck-password="$SC_PASSWORD" \
#   --image-pull-auth=\''{"username":"'${REG_USERNAME}'","password":"'${REG_PASSWORD}'"}'\' \
#   --insecure-skip-tls-verify \
#   --insecure-skip-registry-tls-verify &>/dev/null & disown || true

docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
 deepsecurity/smartcheck-scan-action \
 --image-name "${REGISTRY_HOST}:${REG_PORT}/${TARGET_IMAGE}:${TARGET_IMAGE_TAG}" \
 --smartcheck-host="$SC_SERVICE" \
 --smartcheck-user="$SC_USERNAME" \
 --smartcheck-password="$SC_PASSWORD" \
 --image-pull-auth=\''{"username":"'${REG_USERNAME}'","password":"'${REG_PASSWORD}'"}'\' \
 --insecure-skip-tls-verify \
 --insecure-skip-registry-tls-verify
