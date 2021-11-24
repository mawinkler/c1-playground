#!/bin/bash

set -e

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
CS_POLICY_NAME="$(jq -r '.services[] | select(.name=="container_security") | .policy_name' config.json)"
CS_POLICY_MODE="$(jq -r '.services[] | select(.name=="container_security") | .policy_mode' config.json)"
CS_NAMESPACE="$(jq -r '.services[] | select(.name=="container_security") | .namespace' config.json)"
SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
API_KEY="$(jq -r '.services[] | select(.name=="cloudone") | .api_key' config.json)"
REGION="$(jq -r '.services[] | select(.name=="cloudone") | .region' config.json)"

DEPLOY_RT_YAML=
DEPLOY_RT_JSON=
if [[ $(kubectl config current-context) =~ gke_.*|aks-.*|.*eksctl.io ]]; then
  DEPLOY_RT_YAML=$'runtimeSecurity:\n    enabled: true'
  DEPLOY_RT_JSON=', "runtimeEnabled": true'
fi

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
  kubectl label namespace kube-system --overwrite ignoreAdmissionControl=ignore
}

function cluster_policy {
  # query cluster policy
  printf '%s\n' "query cluster policy id"
  CS_POLICYID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.cloudone.trendmicro.com/api/policies' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: ApiKey '${API_KEY} \
    --header 'api-version: v1' |
    jq -r --arg CS_POLICY_NAME "${CS_POLICY_NAME}" '.policies[] | select(.name==$CS_POLICY_NAME) | .id'
  )

  # create policy if not exist
  if [ "${CS_POLICYID}" == "" ]; then
    printf '%s\n' "creating policy ${CS_POLICY_NAME}"
    #CS_POLICYID=$(
  curl  --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/policies' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: ApiKey '${API_KEY} \
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
    }"
    printf '%s\n' "policy with id ${CS_POLICYID} created"
  else
    printf '%s\n' "reusing cluster policy with id ${CS_POLICYID}"
  fi
}

function create_cluster_object {
  # create cluster object
  printf '%s\n' "create cluster object"
  RESULT=$(
    curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/clusters' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: ApiKey '${API_KEY} \
    --header 'api-version: v1' \
    --data-raw '{
      "name": "'${CLUSTER_NAME//-/_}'",
      "description": "Playground Cluster",
      "policyID": "'${CS_POLICYID}'"'"${DEPLOY_RT_JSON}"'
    }'
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
  endpoint: https://container.${REGION}.cloudone.trendmicro.com
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
  ${DEPLOY_RT_YAML}
  exclusion:
    ## List of namespaces for which Scout Runtime Security feature will not trigger events.
    namespaces:
    - smartcheck
    - container-security
    - kube-node-lease
    - kube-public
    - kube-system
    - prometheus
    - trivy
    - falco
    - starboard
EOF

  # if [[ $(kubectl config current-context) =~ gke_.*|aks-.*|.*eksctl.io ]]; then
  #   echo Running on GKE, AKS or EKS
    helm upgrade \
      container-security \
      --values overrides/overrides-container-security.yml \
      --namespace ${CS_NAMESPACE} \
      --install \
      https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz
  # else
  #   # echo Not running on GKE, AKS or EKS
  #   helm template \
  #     container-security \
  #     --values overrides/overrides-container-security.yml \
  #     --namespace ${CS_NAMESPACE} \
  #     https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz | \
  #       sed -e '/\s*\-\sname:\ FALCO_BPF_PROBE/,/\s*value:/d' | \
  #       kubectl --namespace ${CS_NAMESPACE} apply -f -
  # fi
}

function create_scanner {

  kubectl label namespace smartcheck --overwrite ignoreAdmissionControl=ignore

  # create scanner
  printf '%s\n' "create scanner object"
  RESULT=$(
    curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/scanners' \
      --header 'Content-Type: application/json' \
      --header 'Authorization: ApiKey '${API_KEY} \
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
  endpoint: https://container.${REGION}.cloudone.trendmicro.com
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
kubectl -n smartcheck get service proxy && create_scanner || echo Smartcheck not found
