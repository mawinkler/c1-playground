#!/bin/bash

set -e

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
CS_POLICY_NAME="$(jq -r '.services[] | select(.name=="container_security") | .policy_name' config.json)"
CS_POLICY_MODE="$(jq -r '.services[] | select(.name=="container_security") | .policy_mode' config.json)"
CS_NAMESPACE="$(jq -r '.services[] | select(.name=="container_security") | .namespace' config.json)"
SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
API_KEY="$(jq -r '.services[] | select(.name=="cloudone") | .api_key' config.json)"

function create_namespace {
  printf '%s' "Create container security namespace"

  echo "---" >>up.log
  # create namespace
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: ${CS_NAMESPACE}
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspaces {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespace for container security
  kubectl label namespace smartcheck --overwrite ignoreAdmissionControl=ignore
  kubectl label namespace kube-system --overwrite ignoreAdmissionControl=ignore
}

function cluster_policy {
  # query cluster policy
  printf '%s\n' "query cluster policy id"
  CS_POLICYID=$(
    curl --silent --location --request GET 'https://cloudone.trendmicro.com/api/container/policies' \
    --header 'Content-Type: application/json' \
    --header "api-secret-key: ${API_KEY}" \
    --header 'api-version: v1' |
    jq -r --arg CS_POLICY_NAME "${CS_POLICY_NAME}" '.policies[] | select(.name==$CS_POLICY_NAME) | .id'
  )

  # create policy if not exist
  if [ "${CS_POLICYID}" == "" ]; then
    printf '%s\n' "creating policy ${CS_POLICY_NAME}"
    CS_POLICYID=$(curl --silent --location --request POST 'https://cloudone.trendmicro.com/api/container/policies' \
    --header 'Content-Type: application/json' \
    --header "api-secret-key: ${API_KEY}" \
    --header 'api-version: v1' \
    --data-raw "{
    \"name\": \"${CS_POLICY_NAME}\",
    \"description\": \"Policy for Playground\",
    \"default\": {
    \"rules\": [
      {
        \"action\": \"${CS_POLICY_MODE}\",
        \"type\": \"podSecurityContext\",
        \"enabled\": true,
        \"statement\": {
        \"key\": \"runAsNonRoot\",
        \"value\": \"false\"
        }
      },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"podSecurityContext\",
          \"enabled\": false,
          \"statement\": {
            \"key\": \"hostNetwork\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"podSecurityContext\",
          \"enabled\": false,
          \"statement\": {
            \"key\": \"hostIPC\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"podSecurityContext\",
          \"enabled\": false,
          \"statement\": {
            \"key\": \"hostPID\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"containerSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"runAsNonRoot\",
            \"value\": \"false\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"containerSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"privileged\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"containerSecurityContext\",
          \"enabled\": false,
          \"statement\": {
            \"key\": \"allowPrivilegeEscalation\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"containerSecurityContext\",
          \"enabled\": false,
          \"statement\": {
            \"key\": \"readOnlyRootFilesystem\",
            \"value\": \"false\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"unscannedImage\",
          \"enabled\": true
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"malware\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"count\",
            \"value\": \"0\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"vulnerabilities\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"max-severity\",
            \"value\": \"medium\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"contents\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"max-severity\",
            \"value\": \"medium\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE}\",
          \"type\": \"checklists\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"max-severity\",
            \"value\": \"medium\"
          }
        }
      ]
      }
    }" |
      jq -r ".id")
  else
    printf '%s\n' "reusing cluster policy with id ${CS_POLICYID}"
  fi
}

function create_cluster_object {
  # create cluster object
  printf '%s\n' "create cluster object"
  RESULT=$(
    curl --silent --location --request POST 'https://cloudone.trendmicro.com/api/container/clusters' \
      --header 'Content-Type: application/json' \
      --header "api-secret-key: ${API_KEY}" \
      --header 'api-version: v1' \
      --data-raw "{
      \"name\": \"${CLUSTER_NAME//-/_}\",
      \"description\": \"Playground Cluster\",
      \"policyID\": \"${CS_POLICYID}\",
      \"runtimeEnabled\": true
    }"
  )

  API_KEY_ADMISSION_CONTROLLER=$(echo ${RESULT} | jq -r ".apiKey")
  CS_CLUSTERID=$(echo ${RESULT} | jq -r ".id")
  AP_KEY=$(echo ${RESULT} | jq -r ".runtimeKey")
  AP_SECRET=$(echo ${RESULT} | jq -r ".runtimeSecret")
}

function deploy_container_security {
  ## deploy container security
  printf '%s\n' "deploy container security"

  cat <<EOF >overrides/overrides-container-security.yml
cloudOne:
  apiKey: ${API_KEY_ADMISSION_CONTROLLER}
  endpoint: https://container.us-1.cloudone.trendmicro.com
  runtimeSecurity:
    enabled: true
  admissionController:
    enabled: true
    validationNamespaceSelector:
      matchExpressions:
      - key: ignoreAdmissionControl
        operator: DoesNotExist
    enableKubeSystem: false
    failurePolicy: Ignore
  oversight:
    enabled: true
    syncPeriod: 600s
    enableNetworkPolicyCreation: true
  runtimeSecurity:
    enabled: true
EOF

  helm upgrade \
    container-security \
    --values overrides/overrides-container-security.yml \
    --namespace ${CS_NAMESPACE} \
    --install \
    https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz
}

function create_scanner {
  # create scanner
  printf '%s\n' "create scanner object"
  RESULT=$(
    curl --silent --location --request POST 'https://cloudone.trendmicro.com/api/container/scanners' \
      --header 'Content-Type: application/json' \
      --header "api-secret-key: ${API_KEY}" \
      --header 'api-version: v1' \
      --data-raw "{
      \"name\": \"${CLUSTER_NAME//-/_}\",
      \"description\": \"Playground Image Scanner\"
    }"
  )

  API_KEY_SCANNER=$(echo ${RESULT} | jq -r ".apiKey")
  CS_SCANNERID=$(echo ${RESULT} | jq -r ".id")

  # bind smartcheck to container security
  printf '%s\n' "bind smartcheck to container security"
  cat <<EOF >overrides/overrides-image-security-bind.yml
cloudOne:
  apiKey: ${API_KEY_SCANNER}
EOF

  helm upgrade \
    smartcheck \
    --reuse-values \
    --values overrides/overrides-image-security-bind.yml \
    --namespace ${SC_NAMESPACE} \
    https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz >/dev/null
}

create_namespace
whitelist_namsspaces
cluster_policy
create_cluster_object
deploy_container_security
create_scanner
