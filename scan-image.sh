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


# ##############################################################
# Get Smart Check Config
# ##############################################################
function setup_sc {

  SC_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .username' config.json)"
  SC_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .password' config.json)"
  SC_PORT="$(jq -r '.services[] | select(.name=="smartcheck") | .proxy_service_port' config.json)"
  SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
}

function scan_image {

  if [ ${SYNC} == false ]; then
    eval docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
      deepsecurity/smartcheck-scan-action \
      --image-name "${IMAGE_NAME}" \
      --smartcheck-host="${SC_HOST}:${SC_PORT}" \
      --smartcheck-user="${SC_USERNAME}" \
      --smartcheck-password="${SC_PASSWORD}" \
      --image-pull-auth="${PULL_AUTH}" \
      --insecure-skip-registry-tls-verify \
      --insecure-skip-tls-verify &>/dev/null & disown || true
  else
    docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
      deepsecurity/smartcheck-scan-action \
      --image-name "${IMAGE_NAME}" \
      --smartcheck-host="${SC_HOST}:${SC_PORT}" \
      --smartcheck-user="${SC_USERNAME}" \
      --smartcheck-password="${SC_PASSWORD}" \
      --image-pull-auth="${PULL_AUTH}" \
      --insecure-skip-registry-tls-verify \
      --insecure-skip-tls-verify
  fi
}

# ##############################################################
# Local Kind Cluster
# ##############################################################
function pullpush_registry {

  echo ${REG_PASSWORD} | docker login ${REG_HOST}:${REG_PORT} --username ${REG_USERNAME} --password-stdin
  docker pull ${TARGET_IMAGE}
  docker tag ${TARGET_IMAGE} ${REG_HOST}:${REG_PORT}/${TARGET_IMAGE}
  docker push ${REG_HOST}:${REG_PORT}/${TARGET_IMAGE}
}

function scan_registry {

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

    REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
    printf '%s\n' "Cluster registry is on ${REG_HOST}:${REG_PORT}"
  fi

  printf '%s\n' "Create Registry Pull Auth"
  PULL_AUTH='{"username":"'${REG_USERNAME}'","password":"'${REG_PASSWORD}'"}'
  IMAGE_NAME="${REG_HOST}:${REG_PORT}/${TARGET_IMAGE}"

  # Scan
  scan_image
}

# ##############################################################
# GKE
# ##############################################################
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

function scan_gcp {

  printf '%s\n' "Create Registry Pull Auth"
  JSON_KEY=$(cat ${GCR_SERVICE_ACCOUNT}_keyfile.json | jq tostring)
  PULL_AUTH='{"username":"_json_key","password":'${JSON_KEY}'}'
  IMAGE_NAME="${GCP_HOSTNAME}/${GCP_PROJECTID}/${TARGET_IMAGE}"
  SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  # Scan
  scan_image
}

# ##############################################################
# AKS
# ##############################################################
function pullpush_aks {

  PLAYGROUND_NAME="$(jq -r '.cluster_name' config.json)"
  if [[ $(az group list | jq -r --arg PLAYGROUND_NAME ${PLAYGROUND_NAME} '.[] | select(.name==$PLAYGROUND_NAME) | .name') == "" ]]; then
    printf '%s\n' "Creating Resource Group ${PLAYGROUND_NAME}"
    az group create --name ${PLAYGROUND_NAME} --location westeurope
  else
    printf '%s\n' "Using Resource Group ${PLAYGROUND_NAME}"
  fi

  # Registry names must not have hyphens
  REGISTRY_NAME=$(az acr list --resource-group ${PLAYGROUND_NAME} | jq -r --arg PLAYGROUND_NAME ${PLAYGROUND_NAME//-/} '.[] | select(.name | startswith($PLAYGROUND_NAME)) | .name')
  if [[ ${REGISTRY_NAME} == "" ]]; then
    REGISTRY_NAME=${PLAYGROUND_NAME//-/}$(openssl rand -hex 4)
    printf '%s\n' "Creating Container Registry ${REGISTRY_NAME}"
    az acr create --resource-group ${PLAYGROUND_NAME} --name ${REGISTRY_NAME} --sku Basic
  else
    printf '%s\n' "Using Container Registry ${REGISTRY_NAME}"
  fi

  REGISTRY_LOGINSERVER=$(az acr show --resource-group ${PLAYGROUND_NAME} --name ${REGISTRY_NAME} -o json | jq -r '.loginServer')

  printf '%s\n' "Retrieving Container Registry Credentials"
  az acr update -n ${REGISTRY_NAME} --admin-enabled true 1>/dev/null
  ACR_CREDENTIALS=$(az acr credential show --name ${REGISTRY_NAME})
  ACR_PASSWORD=$(jq -r '.passwords[] | select(.name=="password") | .value' <<< $ACR_CREDENTIALS)
  ACR_USERNAME=$(jq -r '.username' <<< $ACR_CREDENTIALS)

  # Login, pull, push
  printf '%s\n' "Login to Container Registry, pull, tag and push"
  echo ${ACR_PASSWORD} | docker login -u ${ACR_USERNAME} --password-stdin https://${REGISTRY_LOGINSERVER}
  docker pull ${TARGET_IMAGE}
  docker tag ${TARGET_IMAGE} ${REGISTRY_LOGINSERVER}/${TARGET_IMAGE}
  docker push ${REGISTRY_LOGINSERVER}/${TARGET_IMAGE}
}

function scan_aks {

  printf '%s\n' "Create Registry Pull Auth"
  PULL_AUTH='{"username":"'${ACR_USERNAME}'","password":"'${ACR_PASSWORD}'"}'
  IMAGE_NAME="${REGISTRY_LOGINSERVER}/${TARGET_IMAGE}"
  SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  
  # Scan
  scan_image
}

# ##############################################################
# EKS
# ##############################################################
# function pullpush_eks {

#   GCP_HOSTNAME="gcr.io"
#   GCP_PROJECTID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
#   printf '%s\n' "GCP Project is ${GCP_PROJECTID}"
#   GCR_SERVICE_ACCOUNT=service-gcrsvc
#   if test -f "${GCR_SERVICE_ACCOUNT}_keyfile.json"; then
#     printf '%s\n' "Using existing key file"
#   else
#     printf '%s\n' "Creating Service Account"
#     echo ${GCR_SERVICE_ACCOUNT}_keyfile.json
#     gcloud iam service-accounts create ${GCR_SERVICE_ACCOUNT}
#     gcloud projects add-iam-policy-binding ${GCP_PROJECTID} --member "serviceAccount:${GCR_SERVICE_ACCOUNT}@${GCP_PROJECTID}.iam.gserviceaccount.com" --role "roles/storage.admin"
#     gcloud iam service-accounts keys create ${GCR_SERVICE_ACCOUNT}_keyfile.json --iam-account ${GCR_SERVICE_ACCOUNT}@${GCP_PROJECTID}.iam.gserviceaccount.com
#   fi

#   cat ${GCR_SERVICE_ACCOUNT}_keyfile.json | docker login -u _json_key --password-stdin https://${GCP_HOSTNAME}
#   docker pull ${TARGET_IMAGE}
#   docker tag ${TARGET_IMAGE} ${GCP_HOSTNAME}/${GCP_PROJECTID}/${TARGET_IMAGE}
#   docker push ${GCP_HOSTNAME}/${GCP_PROJECTID}/${TARGET_IMAGE}
# }

function scan_eks {

  JSON_KEY=$(cat ${GCR_SERVICE_ACCOUNT}_keyfile.json | jq tostring)
  PULL_AUTH='{"username":"_json_key","password":'${JSON_KEY}'}'
  IMAGE_NAME="${REGISTRY_LOGINSERVER}/${TARGET_IMAGE}"
  SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
                  -o jsonpath='{.status.loadBalancer.ingress[0].dns}')

  # Scan
  scan_image
}

# ##############################################################
# Main
# ##############################################################
setup_sc

if [[ $(kubectl config current-context) =~ gke_.* ]]; then
  printf '%s\n' "Running on GKE"
  pullpush_gcp
  scan_gcp
elif [[ $(kubectl config current-context) =~ .*-aks ]]; then
  printf '%s\n' "Running on AKS"
  pullpush_aks
  scan_aks
elif [[ $(kubectl config current-context) =~ .*eksctl.io ]]; then
  printf '%s\n' "Running on EKS"
  printf '%s\n' "NOT YET IMPLEMENTED"
  exit 0
  pullpush_eks
  scan_eks
else
  printf '%s\n' "Running on local Playground"
  pullpush_registry
  scan_registry
fi
