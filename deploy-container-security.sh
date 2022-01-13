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
  kubectl label namespace kube-system --overwrite ignoreAdmissionControl=true
}

function get_registry_name {

  if [[ $(kubectl config current-context) =~ gke_.* ]]; then
    printf '%s\n' "running on gke"
    GCP_HOSTNAME="gcr.io"
    GCP_PROJECTID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
    REGISTRY=${GCP_HOSTNAME}/${GCP_PROJECTID}
  elif [[ $(kubectl config current-context) =~ .*-aks ]]; then
    printf '%s\n' "running on aks"
    PLAYGROUND_NAME="$(jq -r '.cluster_name' config.json)"
    if [[ $(az group list | jq -r --arg PLAYGROUND_NAME ${PLAYGROUND_NAME} '.[] | select(.name==$PLAYGROUND_NAME) | .name') == "" ]]; then
      printf '%s\n' "creating resource group ${PLAYGROUND_NAME}"
      az group create --name ${PLAYGROUND_NAME} --location westeurope
    else
      printf '%s\n' "using resource group ${PLAYGROUND_NAME}"
    fi
    REGISTRY_NAME=$(az acr list --resource-group ${PLAYGROUND_NAME} | jq -r --arg PLAYGROUND_NAME ${PLAYGROUND_NAME//-/} '.[] | select(.name | startswith($PLAYGROUND_NAME)) | .name')
    if [[ ${REGISTRY_NAME} == "" ]]; then
      REGISTRY_NAME=${PLAYGROUND_NAME//-/}$(openssl rand -hex 4)
      printf '%s\n' "creating container registry ${REGISTRY_NAME}"
      az acr create --resource-group ${PLAYGROUND_NAME} --name ${REGISTRY_NAME} --sku Basic
    else
      printf '%s\n' "using container registry ${REGISTRY_NAME}"
    fi
    REGISTRY=$(az acr show --resource-group ${PLAYGROUND_NAME} --name ${REGISTRY_NAME} -o json | jq -r '.loginServer')
  elif [[ $(kubectl config current-context) =~ .*eksctl.io ]]; then
    printf '%s\n' "running on eks"
    printf '%s\n' "NOT YET IMPLEMENTED"
    exit 0
  else
    printf '%s\n' "running on local playground"
    REG_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' config.json)"
    REG_NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' config.json)"
    OS="$(uname)"
    if [ "${OS}" == 'Linux' ]; then
      REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
    fi
    if [ "${OS}" == 'Darwin' ]; then
      REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                      -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
    fi
    REGISTRY="${REG_HOST}:${REG_PORT}"
  fi
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
    printf '%s\n' "getting registry address"
    get_registry_name
    printf '%s\n' "registry is on ${REGISTRY}"
    printf '%s\n' "creating policy ${CS_POLICY_NAME}"
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
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"podSecurityContext\",
          \"enabled\": true,
          \"statement\": {
          \"key\": \"runAsNonRoot\",
          \"value\": \"false\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"block"}\",
          \"mitigation\": \"log\",
          \"type\": \"podSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"hostNetwork\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"block"}\",
          \"mitigation\": \"log\",
          \"type\": \"podSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"hostIPC\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"block"}\",
          \"mitigation\": \"log\",
          \"type\": \"podSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"hostPID\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"containerSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"runAsNonRoot\",
            \"value\": \"false\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"block"}\",
          \"mitigation\": \"log\",
          \"type\": \"containerSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"privileged\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"containerSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"allowPrivilegeEscalation\",
            \"value\": \"true\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"containerSecurityContext\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"readOnlyRootFilesystem\",
            \"value\": \"false\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"unscannedImage\",
          \"enabled\": true
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"block"}\",
          \"mitigation\": \"log\",
          \"type\": \"malware\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"count\",
            \"value\": \"0\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"vulnerabilities\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"max-severity\",
            \"value\": \"high\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"contents\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"max-severity\",
            \"value\": \"high\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"checklists\",
          \"enabled\": true,
          \"statement\": {
            \"key\": \"max-severity\",
            \"value\": \"high\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"registry\",
          \"enabled\": true,
          \"statement\": {
              \"key\": \"not-equals\",
              \"value\": \"${REGISTRY}\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"tag\",
          \"enabled\": true,
          \"statement\": {
              \"key\": \"equals\",
              \"value\": \"latest\"
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"block"}\",
          \"mitigation\": \"log\",
          \"type\": \"cvssAttackVector\",
          \"enabled\": true,
          \"statement\": {
              \"properties\": [
                  {
                      \"key\": \"cvss-attack-vector\",
                      \"value\": \"network\"
                  },
                  {
                      \"key\": \"max-severity\",
                      \"value\": \"medium\"
                  }
              ]
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"block"}\",
          \"mitigation\": \"log\",
          \"type\": \"cvssAttackComplexity\",
          \"enabled\": true,
          \"statement\": {
              \"properties\": [
                  {
                      \"key\": \"cvss-attack-complexity\",
                      \"value\": \"low\"
                  },
                  {
                      \"key\": \"max-severity\",
                      \"value\": \"medium\"
                  }
              ]
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"block"}\",
          \"mitigation\": \"log\",
          \"type\": \"cvssAvailability\",
          \"enabled\": true,
          \"statement\": {
              \"properties\": [
                  {
                      \"key\": \"cvss-availability\",
                      \"value\": \"high\"
                  },
                  {
                      \"key\": \"max-severity\",
                      \"value\": \"medium\"
                  }
              ]
          }
        },
        {
          \"action\": \"${CS_POLICY_MODE:-"log"}\",
          \"mitigation\": \"log\",
          \"type\": \"checklistProfile\",
          \"enabled\": true,
          \"statement\": {
              \"properties\": [
                  {
                      \"key\": \"checklist-profile\",
                      \"value\": \"pci-dss\"
                  },
                  {
                      \"key\": \"max-severity\",
                      \"value\": \"high\"
                  }
              ]
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
    ## List of namespaces for which Deploy and Continuous feature will not trigger events.
    namespaces:
    - kube-system
    - smartcheck
    - container-security
    # - kube-node-lease
    # - kube-public
    # - prometheus
    # - trivy
    # - falco
    # - starboard
scout:
  excludeSameNamespace: true
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

  kubectl label namespace smartcheck --overwrite ignoreAdmissionControl=true

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
