#!/bin/bash

#######################################
# Main:
# Deploys EKS Cluster
#######################################
function main() {
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
  echo "Creating cluster... (4CPU/16GB per node)"
  gcloud container clusters create ${CLUSTER} \
      --project=${PROJECT_ID} \
      --zone=${ZONE} \
      --release-channel=rapid \
      --machine-type=e2-standard-4 \
      --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"

  echo "Creating rapid-gke-down.sh script"
  cat <<EOF >$PGPATH/bin/rapid-gke-down.sh
#!/bin/bash
gcloud -q container clusters delete ${CLUSTER}
gcloud -q projects delete ${PROJECT_ID}
sudo rm -Rf $PGPATH/auth $PGPATH/certs $PGPATH/audit/audit-webhook.yaml /tmp/passthrough.conf $PGPATH/log/* $PGPATH/services $PGPATH/opa
rm -f service-gcrsvc_keyfile.json
EOF
  chmod +x $PGPATH/bin/rapid-gke-down.sh
  echo "Run rapid-gke-down.sh to tear down everything"
}

function cleanup() {
  $PGPATH/bin/rapid-gke-down.sh
  if [ $? -eq 0 ] ; then
    return
  fi
  false
}

function test() {
  for i in {1..60} ; do
    sleep 5
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -A | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -A | grep -E "([0-9]+)/\1" | wc -l)
    if [ $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ] ; then
      echo ${DEPLOYMENTS_READY}
      return
    fi
  done
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi
