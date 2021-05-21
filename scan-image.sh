#/bin/bash
# ##############################################################################
# Pulls an image, initiates a scan with Smart Check and creates a PDF report
# ##############################################################################
TARGET_IMAGE=${TARGET_IMAGE:-richxsl/rhel7}
TARGET_IMAGE_TAG=${TARGET_IMAGE_TAG:-latest}

SC_NAMESPACE="$(jq -r '.smartcheck_namespace' config.json)"
SC_USERNAME="$(jq -r '.smartcheck_username' config.json)"
SC_PASSWORD="$(jq -r '.smartcheck_password' config.json)"
REG_USERNAME="$(jq -r '.registry_username' config.json)"
REG_PASSWORD="$(jq -r '.registry_password' config.json)"
REG_NAMESPACE="$(jq -r '.registry_namespace' config.json)"
REG_NAME="$(jq -r '.registry_name' config.json)"
REG_PORT="$(jq -r '.registry_port' config.json)"

SC_REGISTRY_PORT="5000"
SC_API_PORT="443"

SERVICE_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
printf '%s\n' "Smart check is on ${SERVICE_HOST}"
REGISTRY_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
printf '%s\n' "Cluster registry is on ${REGISTRY_HOST}"

SC_SERVICE="${SERVICE_HOST}:${SC_API_PORT}"

docker pull ${TARGET_IMAGE}:${TARGET_IMAGE_TAG}
docker tag ${TARGET_IMAGE}:${TARGET_IMAGE_TAG} ${REGISTRY_HOST}:${REG_PORT}/${TARGET_IMAGE}:${TARGET_IMAGE_TAG}
docker push ${REGISTRY_HOST}:${REG_PORT}/${TARGET_IMAGE}:${TARGET_IMAGE_TAG}

docker run --rm --read-only --cap-drop ALL -v /var/run/docker.sock:/var/run/docker.sock --network host \
  deepsecurity/smartcheck-scan-action \
  --image-name "${REGISTRY_HOST}:${REG_PORT}/${TARGET_IMAGE}:${TARGET_IMAGE_TAG}" \
  --smartcheck-host="$SC_SERVICE" \
  --smartcheck-user="$SC_USERNAME" \
  --smartcheck-password="$SC_PASSWORD" \
  --image-pull-auth=\''{"username":"'${REG_USERNAME}'","password":"'${REG_PASSWORD}'"}'\' \
  --findings-threshold "{\"malware\":0,\"vulnerabilities\":{\"defcon1\":0,\"critical\":100,\"high\":100},\"contents\":{\"defcon1\":0,\"critical\":0,\"high\":1},\"checklists\":{\"defcon1\":0,\"critical\":0,\"high\":0}}" \
  --insecure-skip-tls-verify \
  --insecure-skip-registry-tls-verify

docker run --network host mawinkler/scan-report:dev -O \
  --name "${TARGET_IMAGE}" \
  --image_tag "${TARGET_IMAGE_TAG}" \
  --service "${SC_SERVICE}" \
  --username "${SC_USERNAME}" \
  --password "${SC_PASSWORD}" > report_${TARGET_IMAGE//\//_}.pdf

printf '%s\n' "report report_${TARGET_IMAGE}.pdf created"
