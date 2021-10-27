#/bin/bash
# ##############################################################################
# Pulls an image, initiates a scan with Smart Check and creates a PDF report
# ##############################################################################

OS="$(uname)"
# If no parameter was given and TARGET_IMAGE is not set in env, default to rhel7
TARGET_IMAGE=${TARGET_IMAGE:-richxsl/rhel7:latest}
SYNC=false

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -s|--sync)
      SYNC=true
      shift # past argument
      ;;
    *)    # should be the image name and tag
      TARGET_IMAGE=${1}
      shift # past argument
      ;;
  esac
done

echo "Scanning Image ${TARGET_IMAGE}"


function setup_sc {
  SC_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .username' config.json)"
  SC_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .password' config.json)"
  SC_PORT="$(jq -r '.services[] | select(.name=="smartcheck") | .proxy_service_port' config.json)"
  SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
}

function setup_registry {
  REG_USERNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .username' config.json)"
  REG_PASSWORD="$(jq -r '.services[] | select(.name=="playground-registry") | .password' config.json)"
  REG_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' config.json)"
  REG_NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' config.json)"

  if [ "${OS}" == 'Linux' ]; then
    SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
                  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

    REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
    REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  fi

  if [ "${OS}" == 'Darwin' ]; then
    SC_HOST="$(jq -r '.services[] | select(.name=="smartcheck") | .hostname' config.json)"

    REG_HOST="$(jq -r '.services[] | select(.name=="playground-registry") | .hostname' config.json)"
    REG_PORT=443 # ingress
  fi
}

function pullpush_registry {
  echo ${REG_PASSWORD} | docker login ${REG_HOST}:${REG_PORT} --username ${REG_USERNAME} --password-stdin
  docker pull ${TARGET_IMAGE}
  docker tag ${TARGET_IMAGE} ${REG_HOST}:${REG_PORT}/${TARGET_IMAGE}
  docker push ${REG_HOST}:${REG_PORT}/${TARGET_IMAGE}
}

function pullpush_gcp {
  GCP_HOSTNAME="gcr.io"
  GCP_PROJECTID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
  printf '%s\n' "GCP Project is ${GCP_PROJECTID}"
  GCR_SERVICE_ACCOUNT=service-gcrsvc
  if test -f "${GCR_SERVICE_ACCOUNT}_keyfile.json"; then
    printf '%s\n' "Using existing key file"
  else
    printf '%s\n' "Creating Service Account"
    echo ${GCR_SERVICE_ACCOUNT}_keyfile.json
    gcloud iam service-accounts create ${GCR_SERVICE_ACCOUNT}
    gcloud projects add-iam-policy-binding ${GCP_PROJECTID} --member "serviceAccount:${GCR_SERVICE_ACCOUNT}@${GCP_PROJECTID}.iam.gserviceaccount.com" --role "roles/storage.admin"
    gcloud iam service-accounts keys create ${GCR_SERVICE_ACCOUNT}_keyfile.json --iam-account ${GCR_SERVICE_ACCOUNT}@${GCP_PROJECTID}.iam.gserviceaccount.com
  fi

  cat ${GCR_SERVICE_ACCOUNT}_keyfile.json | docker login -u _json_key --password-stdin https://${GCP_HOSTNAME}
  docker pull ${TARGET_IMAGE}
  docker tag ${TARGET_IMAGE} ${GCP_HOSTNAME}/${GCP_PROJECTID}/${TARGET_IMAGE}
  docker push ${GCP_HOSTNAME}/${GCP_PROJECTID}/${TARGET_IMAGE}
}

function scan_registry {
  if [ "${OS}" == 'Darwin' ]; then
    REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
    printf '%s\n' "Cluster registry is on ${REG_HOST}:${REG_PORT}"
  fi

  if [ ${SYNC} == false ]; then
    eval docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
      deepsecurity/smartcheck-scan-action \
      --image-name "${REG_HOST}:${REG_PORT}/${TARGET_IMAGE}" \
      --smartcheck-host="${SC_HOST}:${SC_PORT}" \
      --smartcheck-user="${SC_USERNAME}" \
      --smartcheck-password="${SC_PASSWORD}" \
      --image-pull-auth=\''{"username":"'${REG_USERNAME}'","password":"'${REG_PASSWORD}'"}'\' \
      --insecure-skip-tls-verify \
      --insecure-skip-registry-tls-verify &>/dev/null & disown || true
  else
    docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
      deepsecurity/smartcheck-scan-action \
      --image-name "${REG_HOST}:${REG_PORT}/${TARGET_IMAGE}" \
      --smartcheck-host="${SC_HOST}:${SC_PORT}" \
      --smartcheck-user="${SC_USERNAME}" \
      --smartcheck-password="${SC_PASSWORD}" \
      --image-pull-auth=\''{"username":"'${REG_USERNAME}'","password":"'${REG_PASSWORD}'"}'\' \
      --insecure-skip-tls-verify \
      --insecure-skip-registry-tls-verify
  fi
}

function scan_gcp {

  JSON_KEY=$(cat ${GCR_SERVICE_ACCOUNT}_keyfile.json | jq tostring)
  PULL_AUTH='{"username":"_json_key","password":'${JSON_KEY}'}'
  if [ ${SYNC} == false ]; then
    eval docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
      deepsecurity/smartcheck-scan-action \
      --image-name "${GCP_HOSTNAME}/${GCP_PROJECTID}/${TARGET_IMAGE}" \
      --smartcheck-host="${SC_HOST}:${SC_PORT}" \
      --smartcheck-user="${SC_USERNAME}" \
      --smartcheck-password="${SC_PASSWORD}" \
      --image-pull-auth=''${PULL_AUTH}'' \
      --insecure-skip-tls-verify \
      --insecure-skip-registry-tls-verify &>/dev/null & disown || true
  else
    docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
      deepsecurity/smartcheck-scan-action \
      --image-name "${GCP_HOSTNAME}/${GCP_PROJECTID}/${TARGET_IMAGE}" \
      --smartcheck-host="${SC_HOST}:${SC_PORT}" \
      --smartcheck-user="${SC_USERNAME}" \
      --smartcheck-password="${SC_PASSWORD}" \
      --image-pull-auth="${PULL_AUTH}" \
      --insecure-skip-tls-verify \
      --insecure-skip-registry-tls-verify
  fi
}

if [[ $(kubectl config current-context) =~ gke_.* ]]; then
  echo Running on GKE
  setup_sc
  pullpush_gcp
  SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
                  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  scan_gcp
else
  setup_sc
  setup_registry
  printf '%s\n' "Smart check is on ${SC_HOST}:${SC_PORT}"
  printf '%s\n' "Cluster registry is on ${REG_HOST}:${REG_PORT}"
  pullpush_registry
  scan_registry
fi
