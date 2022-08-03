#!/bin/bash

#######################################
#
# WORK IN PROGRESS
#
# Requirements:
#   - ./tools.sh
#   - clusters/rapid-aks.sh
#   - ./deploy-smartcheck.sh
#######################################

set -e

# Source helpers
. ./playground-helpers.sh

# Future use
API_KEY="$(jq -r '.services[] | select(.name=="cloudone") | .api_key' config.json)"
REGION="$(jq -r '.services[] | select(.name=="cloudone") | .region' config.json)"
INSTANCE="$(jq -r '.services[] | select(.name=="cloudone") | .instance' config.json)"
if [ ${INSTANCE} = null ]; then
  INSTANCE=cloudone
fi

GITHUB_USERNAME="$(jq -r '.services[] | select(.name=="pipeline") | .github_username' config.json)"
GITHUB_EMAIL="$(jq -r '.services[] | select(.name=="pipeline") | .github_email' config.json)"
APP_NAME="$(jq -r '.services[] | select(.name=="pipeline") | .github_project' config.json)"
TREND_AP_KEY="$(jq -r '.services[] | select(.name=="pipeline") | .appsec_key' config.json)"
TREND_AP_SECRET="$(jq -r '.services[] | select(.name=="pipeline") | .appsec_secret' config.json)"
DOCKER_USERNAME="$(jq -r '.services[] | select(.name=="pipeline") | .docker_username' config.json)"
DOCKER_PASSWORD="$(jq -r '.services[] | select(.name=="pipeline") | .docker_password' config.json)"
DSSC_USERNAME="$(jq -r '.services[] | select(.name=="smartcheck") | .username' config.json)"
DSSC_PASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .password' config.json)"
DSSC_REGUSER="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_username' config.json)"
DSSC_REGPASSWORD="$(jq -r '.services[] | select(.name=="smartcheck") | .reg_password' config.json)"
DEVOPS_ORGANIZATION="$(jq -r '.services[] | select(.name=="pipeline") | .azure_devops_organization' config.json)"
AZURE_DEVOPS_EXT_PAT="$(jq -r '.services[] | select(.name=="pipeline") | .azure_devops_pat' config.json)"

mkdir -p overrides

export APP_PORT=80
export REGISTRY_NAME=c1appsecuploaderregistry$(openssl rand -hex 4)
export CLUSTER_NAME=appcluster$(openssl rand -hex 4)

cat <<EOF >pipeline-azure-down.sh
set -e
EOF
chmod +x pipeline-azure-down.sh

#######################################
# Create Group, ACR, AKS & Project
# Globals:
#   AWS_ACCOUNT_ID
#   AWS_REGION
# Arguments:
#   None
# Outputs:
#   CODEBUILD_ROLE_NAME
#######################################
function create_group_acr_aks_project() {
  printf '%s\n' "Create Resource Group"
  az group create --name ${APP_NAME} --location westeurope

  echo "az group delete --name ${APP_NAME} -y" >> pipeline-azure-down.sh

  printf '%s\n' "Create ACR"
  az acr create --resource-group ${APP_NAME} --name ${REGISTRY_NAME} --sku Basic

  printf '%s\n' "Create AKS"
  az aks create \
      --resource-group ${APP_NAME} \
      --name ${CLUSTER_NAME} \
      --node-count 2 \
      --enable-addons monitoring \
      --generate-ssh-keys
  az aks get-credentials --resource-group ${APP_NAME} --name ${CLUSTER_NAME}

  printf '%s\n' "Create Project"
  az devops project create \
    --name ${APP_NAME} \
    --description 'Project for the Uploader' \
    --source-control git \
    --visibility private \
    --org ${DEVOPS_ORGANIZATION}

  echo "az devops project delete --id ${PROJECT_ID} -y" >> pipeline-azure-down.sh
}

#######################################
# Prepare the Repository
# Globals:
#   GITHUB_USERNAME
#   GITHUB_EMAIL
#   APP_NAME
#   AWS_REGION
#   TREND_AP_KEY
#   TREND_AP_SECRET
# Arguments:
#   None
# Outputs:
#   None
#######################################
function prepare_repo() {
  printf '%s\n' "Preparing the Repository"

  if [ ! -d ${APP_NAME} ]; then
    git clone https://github.com/${GITHUB_USERNAME}/${APP_NAME}.git
    cd ${APP_NAME}
    git init
    git remote remove azure ; \
      git remote add azure https://${AZURE_DEVOPS_EXT_PAT}@${DEVOPS_ORGANIZATION//https:\/\//}/${APP_NAME}/_git/${APP_NAME}
    git add .
    git commit . -m "Initial commit"
    git push azure master

    # Enable the credential helper for git to modify `~/.gitconfig`
    git config --global credential.helper '!aws codecommit credential-helper $@'
    git config --global credential.UseHttpPath true

    cd ..
  else
    printf '%s\n' "Local Repository already exists"
  fi
}

function create_service_endpoint_registry() {
  printf '%s\n' "Registry Service Endpoint"
  export REGISTRY_LOGINSERVER=$(az acr show --resource-group ${APP_NAME} --name ${REGISTRY_NAME} -o json | jq -r '.loginServer')
  export REGISTRY_ID=$(az acr show --resource-group ${APP_NAME} --name ${REGISTRY_NAME} -o json | jq -r '.id')
  export TENANT_ID=$(az account show | jq -r '.homeTenantId')
  export SUBSCRIPTION_ID=$(az account show | jq -r '.id')
  export SUBSCRIPTION_NAME=$(az account show | jq -r '.name')

  cat <<EOF > service-endpoint-acr.json
  {
      "authorization": {
          "scheme": "ServicePrincipal",
          "parameters": {
              "loginServer": "${REGISTRY_LOGINSERVER}",
              "scope": "${REGISTRY_ID}",
              "servicePrincipalId": "placeholder",
              "tenantId": "${TENANT_ID}"
          }
      },
      "data": {
          "appObjectId": "",
          "azureSpnPermissions": "",
          "azureSpnRoleAssignmentId": "",
          "registryId": "${REGISTRY_ID}",
          "registrytype": "ACR",
          "spnObjectId": "",
          "subscriptionId": "${SUBSCRIPTION_ID}",
          "subscriptionName": "${SUBSCRIPTION_NAME}"
      },
      "description": "",
      "groupScopeId": null,
      "name": "${REGISTRY_NAME}-sc",
      "operationStatus": null,
      "readersGroup": null,
      "serviceEndpointProjectReferences": null,
      "type": "dockerregistry",
      "url": "https://${REGISTRY_LOGINSERVER}",
      "isShared": false,
      "owner": "library"
  }
EOF

  export REGISTRY_SC=$(az devops service-endpoint create --service-endpoint-configuration service-endpoint-acr.json --organization ${DEVOPS_ORGANIZATION} --project ${APP_NAME} --verbose 2>/dev/null | jq -r ".id")
  az devops service-endpoint update --id ${REGISTRY_SC} --enable-for-all true --org ${DEVOPS_ORGANIZATION} -p ${APP_NAME}
}

function create_service_endpoint_kubernetes() {
  printf '%s\n' "Kubernetes Service Endpoint"
  export CLUSTER_ID=$(az aks list --resource-group ${APP_NAME} | jq -r --arg CLUSTER_NAME ${CLUSTER_NAME} '.[] | select(.name=$CLUSTER_NAME) | .id')
  export CLUSTER_FQDN=$(az aks list --resource-group ${APP_NAME} | jq -r --arg CLUSTER_NAME ${CLUSTER_NAME} '.[] | select(.name=$CLUSTER_NAME) | .fqdn')
  export PROJECT_ID=$(az devops project list | jq -r --arg APP_NAME ${APP_NAME} '.value[] | select(.name==$APP_NAME) | .id')

  cat <<EOF > service-endpoint-aks.json
  {
    "authorization": {
          "scheme": "Kubernetes",
          "parameters": {
            "azureEnvironment": "AzureCloud",
            "azureTenantId": "${TENANT_ID}"
            }
      },
    "createdBy": {},
    "data": {
        "authorizationType": "AzureSubscription",
        "azureSubscriptionId": "${SUBSCRIPTION_ID}",
        "azureSubscriptionName": "${SUBSCRIPTION_NAME}",
        "clusterId": "${CLUSTER_ID}",
        "namespace": "default",
        "clusterAdmin": "true"

      },
      "isShared": false,
      "name": "${CLUSTER_NAME}-sc",
      "owner": "library",
      "type": "kubernetes",
      "url": "https://${CLUSTER_FQDN}",
      "administratorsGroup": null,
      "description": "",
      "groupScopeId": null,
      "operationStatus": null,
      "readersGroup": null,
      "serviceEndpointProjectReferences": [
        {
          "description": "",
          "name": "${CLUSTER_NAME}-sc",
          "projectReference": {
            "id": "${PROJECT_ID}",
            "name": "${APP_NAME}"
          }
        }
      ]
  }
EOF

  export APP_CLUSTER_SC=`az devops service-endpoint create --service-endpoint-configuration service-endpoint-aks.json --organization "${DEVOPS_ORGANIZATION}" --project "${APP_NAME}" --verbose | jq -r ".id"`
  az devops service-endpoint update --id ${APP_CLUSTER_SC} --enable-for-all true  --org ${DEVOPS_ORGANIZATION} -p ${APP_NAME}

  # Enable authentication with ACR from AKS. This integration assigns the AcrPull role to the managed identity associated to the AKS Cluster.
  az aks update --name ${CLUSTER_NAME} --resource-group ${APP_NAME} --attach-acr ${REGISTRY_NAME}
}

function create_environment() {
  printf '%s\n' "Create Environment"
  cat <<EOF > params.json
  {
    "name": "dev",
    "description": "My dev environment"
  }
EOF

  export ENVIRONMENT_ID=$(az devops invoke --area distributedtask --resource environments --route-parameters project=${APP_NAME} --org ${DEVOPS_ORGANIZATION} --http-method POST --in-file params.json --api-version "6.0-preview" | jq -r '.id')

  # Add Kubernetes resource to environment
  # POST https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments/{environmentId}/providers/kubernetes?api-version=6.0-preview.1
  cat <<EOF > params.json
  {
    "clusterName": "${CLUSTER_NAME}",
    "name": "default",
    "namespace": "default",
    "serviceEndpointId": "${APP_CLUSTER_SC}",
    "tags": "[]"
  }
EOF

  az devops invoke --area distributedtask --resource kubernetes --route-parameters project=${APP_NAME} environmentId=${ENVIRONMENT_ID} --org ${DEVOPS_ORGANIZATION} --http-method POST --in-file params.json --api-version "6.0-preview" --verbose
}

function create_manifests() {
  printf '%s\n' "Create Kubernetes Manifests"
  mkdir -p manifests

  cat <<EOF > manifests/deployment.yml
  apiVersion : apps/v1
  kind: Deployment
  metadata:
    name: ${APP_NAME}
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: ${APP_NAME}
    template:
      metadata:
        labels:
          app: ${APP_NAME}
      spec:
        containers:
        - name: ${APP_NAME}
          image: ${REGISTRY_LOGINSERVER}/${APP_NAME}
          ports:
          - containerPort: ${APP_PORT}
EOF

  cat <<EOF > manifests/service.yml
  apiVersion: v1
  kind: Service
  metadata:
    name: ${APP_NAME}
  spec:
    type: LoadBalancer
    ports:
    - port: ${APP_PORT} 
    selector:
      app: ${APP_NAME}
EOF
}

function create_pipeline() {
  printf '%s\n' "Create YAML-Pipeline"
  cat <<EOF > azure-pipelines.yml
  # Deploy to Azure Kubernetes Service
  # Build and push image to Azure Container Registry; Deploy to Azure Kubernetes Service
  # https://docs.microsoft.com/azure/devops/pipelines/languages/docker

  trigger:
  - master

  resources:
  - repo: self

  variables:
    dockerRegistryServiceConnection: '${REGISTRY_SC}'
    clusterServiceConnection: '${APP_CLUSTER_SC}'
    imageRepository: '${APP_NAME}'
    containerRegistry: '${REGISTRY_LOGINSERVER}'
    dockerfilePath: '**/Dockerfile'
    tag: '\$(Build.BuildId)'
    imagePullSecret: '${REGISTRY_NAME}-auth'

    # Agent VM image name
    vmImageName: 'ubuntu-latest'

  stages:
  - stage: Build
    displayName: Build stage
    jobs:
    - job: Build
      displayName: Build
      pool:
        vmImage: \$(vmImageName)
      steps:
      - task: Docker@2
        displayName: Build
        inputs:
          command: buildAndPush
          repository: \$(imageRepository)
          dockerfile: \$(dockerfilePath)
          containerRegistry: \$(dockerRegistryServiceConnection)
          tags: |
            \$(tag)
            latest

      - upload: manifests
        artifact: manifests

  - stage: Deploy
    displayName: Deploy stage
    dependsOn: Build

    jobs:
    - deployment: Deploy
      displayName: Deploy
      pool:
        vmImage: \$(vmImageName)
      environment: 'dev'
      strategy:
        runOnce:
          deploy:
            steps:
            - task: KubernetesManifest@0
              displayName: Creating imagePullSecret
              inputs:
                action: createSecret
                secretName: \$(imagePullSecret)
                dockerRegistryEndpoint: \$(dockerRegistryServiceConnection)
                kubernetesServiceConnection: \$(clusterServiceConnection)

            - task: KubernetesManifest@0
              displayName: Deploying to Kubernetes cluster
              inputs:
                action: deploy
                manifests: |
                  \$(Pipeline.Workspace)/manifests/deployment.yml
                  \$(Pipeline.Workspace)/manifests/service.yml
                imagePullSecrets: |
                  \$(imagePullSecret)
                containers: |
                  \$(containerRegistry)/\$(imageRepository):\$(tag)
                kubernetesServiceConnection: \$(clusterServiceConnection)
EOF

  # Create Pipeline
  export PIPELINE_NAME=${APP_NAME}
  export PIPELINE_ID=$(az pipelines create --name ${PIPELINE_NAME} \
    --description "Pipeline for ${PIPELINE_NAME}" \
    --project "${APP_NAME}" \
    --repository "${APP_NAME}" \
    --branch master  \
    --repository-type tfsgit \
    --skip-first-run \
    --yml-path "azure-pipelines.yml" | jq -r ".id")

  cat <<EOF > params.json
  {
      "pipelines": [
          {
              "id": "${PIPELINE_ID}",
              "authorized": "true"
          }
      ]
  }
EOF

  # Allow Pipeline access to ACR
  az devops invoke --area pipelinepermissions --resource pipelinePermissions --route-parameters project=${APP_NAME} resourceType=endpoint resourceId=${REGISTRY_SC} --in-file params.json --http-method PATCH --api-version "6.0-preview"

  # Allow Pipeline access to AKS
  az devops invoke --area pipelinepermissions --resource pipelinePermissions --route-parameters project=${APP_NAME} resourceType=endpoint resourceId=${APP_CLUSTER_SC} --in-file params.json --http-method PATCH --api-version "6.0-preview"

  # Allow Pipeline access to Environment
  az devops invoke --area pipelinepermissions --resource pipelinePermissions --route-parameters project=${APP_NAME} resourceType=environment resourceId=${ENVIRONMENT_ID} --in-file params.json --http-method PATCH --api-version "6.0-preview"

  # Assign the desired role to the service principal. Modify the '--role' argument
  # value as desired:
  # acrpull:     pull only
  # acrpush:     push and pull
  # owner:       push, pull, and assign roles
  # az role assignment create --assignee ${APP_CLUSTER_SC} --scope ${REGISTRY_ID} --role acrpull
}

#######################################
# Populate the CodeCommit Repository
# Globals:
#   APP_NAME
# Arguments:
#   None
# Outputs:
#   None
#######################################
function populate_project_repo() {
  printf '%s\n' "Populating the Project Repository"

  cd ${APP_NAME}

  git add azure-pipelines.yml manifests
  git commit . -m "Initial commit"
  git push azure master

  cd ..
}

function main() {

  if is_aks ; then
    create_group_acr_aks_project
    prepare_repo
    create_service_endpoint_registry
    create_service_endpoint_kubernetes
    create_environment
    create_manifests
    create_pipeline
    populate_project_repo
  else
    printf '%s\n' "Script requires an AKS cluster"
    exit 0
  fi
  echo "Run pipeline-azure-down.sh to tear down everything"
}

function cleanup() {
  printf '%s\n' "Not implemented"
  exit 0
}

function test() {
  printf '%s\n' "Not implemented"
  exit 0
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi
