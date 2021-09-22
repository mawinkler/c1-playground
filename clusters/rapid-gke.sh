#!/bin/bash

# Exports
export ZONE=europe-west2-b
export CLUSTER=playground

# Setup a project
echo "Create project..."
export PROJECT_ID=playground-$(openssl rand -hex 4)
gcloud projects create ${PROJECT_ID} --name devops-training
gcloud -q config set project ${PROJECT_ID}
gcloud -q config set compute/zone $ZONE

# Enable billing
echo "Enable billing..."
export BILLING_ACCOUNT=$(gcloud alpha billing accounts list | sed -n 's/\([0-9A-F]\{1,6\}-[0-9A-F]\{1,6\}-[0-9A-F]\{1,6\}\)\s.*/\1/p')
gcloud alpha billing projects link ${PROJECT_ID} \
  --billing-account ${BILLING_ACCOUNT}

# Enable APIs
echo "Enable APIs..."
gcloud services enable \
    container.googleapis.com \
    containerregistry.googleapis.com \
    cloudbuild.googleapis.com \
    sourcerepo.googleapis.com \
    compute.googleapis.com \
    cloudresourcemanager.googleapis.com

# Create Cluster
echo "Creating cluster..."
gcloud container clusters create ${CLUSTER} \
    --project=${PROJECT_ID} \
    --zone=${ZONE} \
    --release-channel=rapid \
    --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"

echo "Done."

echo "Delete project run: gcloud -q projects delete ${PROJECT_ID}"