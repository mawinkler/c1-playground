#/bin/bash
# ##############################################################################
# Pulls an image, initiates a scan with Smart Check and creates a PDF report
# ##############################################################################
TARGET_IMAGE=richxsl/rhel7
TARGET_IMAGE_TAG=latest

SC_NAMESPACE="$(jq -r '.smartcheck_namespace' config.json)"
SC_USERNAME="$(jq -r '.smartcheck_username' config.json)"
SC_PASSWORD="$(jq -r '.smartcheck_password' config.json)"
SC_REG_USERNAME="$(jq -r '.smartcheck_reg_username' config.json)"
SC_REG_PASSWORD="$(jq -r '.smartcheck_reg_password' config.json)"

SC_REGISTRY_PORT="5000"
SC_API_PORT="443"

SERVICE_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
printf '%s\n' "smart check is on ${SERVICE_HOST}"

SC_REGISTRY="${SERVICE_HOST}:${SC_REGISTRY_PORT}"
SC_SERVICE="${SERVICE_HOST}:${SC_API_PORT}"

docker pull ${TARGET_IMAGE}:${TARGET_IMAGE_TAG}

docker run -v /var/run/docker.sock:/var/run/docker.sock --network host \
  deepsecurity/smartcheck-scan-action \
  --image-name "${TARGET_IMAGE}:${TARGET_IMAGE_TAG}" \
  --preregistry-host="$SC_REGISTRY" \
  --smartcheck-host="$SC_SERVICE" \
  --smartcheck-user="$SC_USERNAME" \
  --smartcheck-password="$SC_PASSWORD" \
  --insecure-skip-tls-verify \
  --insecure-skip-registry-tls-verify \
  --preregistry-scan \
  --preregistry-user "$SC_REG_USERNAME" \
  --preregistry-password "$SC_REG_PASSWORD"

docker run --network host mawinkler/scan-report:dev -O \
  --name "${TARGET_IMAGE}" \
  --image_tag "${TARGET_IMAGE_TAG}" \
  --service "${SC_SERVICE}" \
  --username "${SC_USERNAME}" \
  --password "${SC_PASSWORD}" > report_${TARGET_IMAGE}.pdf

printf '%s\n' "report report_${TARGET_IMAGE}.pdf created"
