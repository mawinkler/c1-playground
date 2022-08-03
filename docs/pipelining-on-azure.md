# Pipelining on Azure

- [Pipelining on Azure](#pipelining-on-azure)
  - [Requirements & Preparations](#requirements--preparations)
  - [Deployment](#deployment)
  - [Further Reading](#further-reading)
  - [Tear Down](#tear-down)

## Requirements & Preparations

Pipelining on Azure requires an AKS cluster, of course. So this pipeline does not work with any other Playground variant.

At a minimum, the following steps needs to be executed prior running the `deploy-pipeline-azure.sh`-script:

```sh
# Playground tools
./tools.sh

# Build AKS cluster
clusters/rapid-aks.sh

# Deploy Smart Check
./deploy-smartcheck.sh
```

## Deployment

Run

```sh
./deploy-pipeline-azure.sh
```

This script automates the following:

1. create_group_acr_aks_project
2. prepare_repo
3. create_service_endpoint_registry
4. create_service_endpoint_kubernetes
5. create_environment
6. create_manifests
7. create_pipeline
8. populate_project_repo

The pipeline builds the container image, pushes it to ACR, scans the image with Smart Check and finally deploys it to AKS.

The deployment obviously can fail if you're running Cloud One Container Security on the cluster, since the image will contain vulnerabilitlies. So it just depends on you and your defined policy.

If everything works you'll have a running uploader demo on your cluster. Query the URL by `kubectl -n default get svc` and upload some malware, if you want

## Further Reading

## Tear Down

To tear down the pipeline simply run the auto-generated script

```sh
pipeline-azure-down.sh
```
