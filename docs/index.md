# Playground Simplicity

Ultra fast and slim kubernetes playground.

![alt text](https://raw.githubusercontent.com/mawinkler/c1-playground/master/images/video-bootstrap.gif "bootstrap")

## Latest News

!!! Announcing the ***Playground SIMPLICITY*** !!!

In a nutshell:

- Bootstrapping directly from the clouds. It will attempt to upgrade already installed tools to the latest available version.  

  ```sh
  curl -fsSL https://raw.githubusercontent.com/mawinkler/c1-playground/master/bin/playground | bash
  ```

- No `git clone`.
- No `daemon.json` configuration.
- It got a menu :-). Run it via `playground` from anywhere on your system.
- Bootstrapping has never been easier!

## Requirements and Support Matrix

The Playground is designed to work on these operating systems

- Ubuntu Bionic and newer
- Cloud9 with Ubuntu

for a locally running cluster.

The deployment scripts for managed cloud clusters are supporting the following cluster types:

- GKE
- EKS
- AKS

### Supported Cluster Variants

Originally, the playground was designed to create a kubernetes cluster locally on the host running the playground scripts. This is still the fastest way of getting a cluster up and running.

In addition to the local cluster, it is also possible to use most functionality of the playground on the managed clusters of the main cloud providers AWS, GCP & Azure as well. Going into this direction requires you to work on a Linux shell and an authenticated CLI to the chosen cloud provider (`aws`, `az` or `gcloud`).

### Support Matrix

Add-On | **Ubuntu**<br>*Local* | **Cloud9**<br>*Local* | GKE<br>*Cloud* | EKS<br>*Cloud* | AKS<br>*Cloud*
------ | ------ | ----- | --- | --- | ---
Internal Registry | X | X | GCR | ECR | ACR
Scanning Scripts | X |X | X | X | X
C1CS Admission & Continuous | X | X | X | X | X
C1CS Runtime Security | X (1) | X | X | X | X
Falco | X | X | X | X | X | X
Gatekeeper | X |X | X | X | X | X
Open Policy Agent | X | X | X | X | X | X
Prometheus & Grafana | X | X | X | X | X | X
Trivy | X | X | X | X | X | X
Cilium | X | X | X | X | X
Kubescape | X | X | X | X | X | X
Harbor | X (2) | | | | | |
Smarthome | X (2) | | | | | |
Pipelines | | | | X | |
Jenkins | X | | X | | | |
GitLab | X | | X | | | |

*Local* means, the cluster will run on the machine you're working on.

*Cloud* means, that the cluster is a cloud managed cluster using the named service.

*(1)* Depending on the Kernel in use. Currently the kernels 4.15.x and 5.4.x are supported.

*(2)* In development.

## CLI Commands of the Playground

Besides the obvious cli tools like `kubectl`, `docker`, etc. the Playground offers you additional commands shown in the table below (and more):

Command | Function
------- | --------
playground | The Playground's menu
scan-image | Scan an image using Smart Check<br>Example:<br>`scan-image nginx:latest`
scan-namespace | Scans all images in use within the current namespace<br>Example:<br>`kubectl config set-context --current --namespace <NAMESPACE>`<br>`scan-namespace`
collect-logs-sc | Collects logs from Smart Check
collect-logs-cs | Collects logs from Container Security
stern | Tail logs from multiple pods simultaneously<br>Example:<br>`stern -n trendmicro-system . -t -s2m`
syft | See [github.com/anchore/syft](https://github.com/anchore/syft)
grype | See [github.com/anchore/grype](https://github.com/anchore/grype)
k9s | See [k9scli.io](https://k9scli.io/)

### Playgrounds Menu Structure

The structure of the menu:


```
playground
├── Manage Tools and CSPs...
│   ├── Update Tools & Playground
│   ├── Install/Update CLI...
│   │   ├── AWS CLI
│   │   ├── Azure CLI
│   │   └── GCP CLI
│   └── Authenticate to CSP...
│       ├── Authenticate to AWS
│       ├── Authenticate to Azure
│       └── Authenticate to GCP
├── Manage Clusters...
│   ├── Create a Cluster...
│   │   ├── Local Cluster
│   │   ├── Elastic Kubernetes Cluster
│   │   ├── Azure Kubernetes Cluster
│   │   └── Google Kubernetes Engine
│   ├── Select Cluster Context...
│   │   └── (Select a Cluster Context)
│   └── (Danger Zone) Tear Down Cluster...
│       ├── Local Cluster
│       ├── Elastic Kubernetes Cluster
│       ├── Azure Kubernetes Cluster
│       └── Google Kubernetes Engine
├── Manage Services...
│   ├── Deploy Services...
│   │   └── (Services List)
│   ├── (Danger Zone) Delete Services...
│   │   └── (Services List)
│   ├── Display Namespaces, LoadBalancers, Deployments & DaemonSets
│   └── Display Services, Addresses and Credentials
└── Manage Configuration...
    ├── Display Disk Space
    ├── Edit Configuration
    └── Edit daemon.json
```

## Good to Know

If you're curious check out the `templates`-directory which holds the configuration of all components. Modify at your own risk ;-).
