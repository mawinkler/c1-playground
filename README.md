# Playground

- [Playground](#playground)
  - [Requirements and Support Matrix](#requirements-and-support-matrix)
    - [Supported Cluster Variants](#supported-cluster-variants)
    - [Suport Matrix](#suport-matrix)
  - [Prepare your Environment](#prepare-your-environment)
    - [Ubuntu with built in Cluster](#ubuntu-with-built-in-cluster)
    - [MacOS with built in Cluster](#macos-with-built-in-cluster)
    - [Cloud9 with built in Cluster](#cloud9-with-built-in-cluster)
    - [Ubuntu or MacOS with Managed Cluster](#ubuntu-or-macos-with-managed-cluster)
    - [Cloud9 with AWS EKS Managed Cluster](#cloud9-with-aws-eks-managed-cluster)
  - [Get the Playground](#get-the-playground)
  - [Configure](#configure)
  - [Start](#start)
    - [Create Playgrounds built-in Cluster](#create-playgrounds-built-in-cluster)
    - [Create GKE, EKS or AKS Clusters](#create-gke-eks-or-aks-clusters)
  - [Deployments](#deployments)
  - [Tear Down](#tear-down)
    - [Tear Down Ubuntu Local, MacOS Local or Cloud9 Local Clusters](#tear-down-ubuntu-local-macos-local-or-cloud9-local-clusters)
    - [Tear Down GKE, EKS or AKS Clusters](#tear-down-gke-eks-or-aks-clusters)
  - [Add-Ons](#add-ons)
  - [Play with the Playground](#play-with-the-playground)
  - [Demo Scripts](#demo-scripts)
    - [Deployment Control Demo](#deployment-control-demo)
    - [Runtime Security Demo](#runtime-security-demo)
  - [Experimenting](#experimenting)
    - [Migrate](#migrate)
  - [Testing the Playground](#testing-the-playground)
  - [TODO](#todo)

Ultra fast and slim kubernetes playground.

The playground runs on local or Cloud9 based Ubuntu servers, GKE, AKS, EKS and most parts on MacOS as well.

## Requirements and Support Matrix

> ***Note:*** The Playgound is designed to work on these operating systems
>
> - Ubuntu Bionic and newer
> - Cloud9 with Ubuntu
> - MacOS 10+
>
> for a locally running cluster.
>
> The deployment scripts for managed cloud clusters are supporting the following cluster types:
>
> - GKE
> - EKS
> - AKS

### Supported Cluster Variants

Originally, the playground was designed to create a kubernetes cluster locally on the host running the playground scripts. This is still the fastest way of getting a cluster up and running.

In addition to the local cluster, it is also possible to use most functionality of the playground on the managed clusters of the main cloud providers AWS, GCP & Azure as well. Going into this direction requires you to work on a Linux / MacOS shell and an authenticated CLI to the chosen cloud provider (`aws`, `az` or `gcloud`).

Before or after you've authenticated to the cloud, be sure to install the required tools as described in the next section.

Within the directory `clusters` are scripts to rapidly create a kubernetes cluster on the three major public clouds. This comes in handy, if you want to play on these public clouds or have no possibility to run an Ubuntu or MacOS.

> ***NOTE:*** Do not run `up.sh` or `down.sh` when using these clusters.

### Suport Matrix

Add-On | **Ubuntu**<br>*Local* | **MacOS**<br>*Local* | **Cloud9**<br>*Local* | GKE<br>*Cloud* | EKS<br>*Cloud* | AKS<br>*Cloud*
------ | ------ | ------ | ----- | --- | --- | ---
Internal Registry | X | X | X | | |
Scanning Scripts | X | X | X | X | X | X
C1CS Admission & Continuous | X | X | X | X | X | X
C1CS Runtime Security | X (1) | | X | X | X | X
Falco | X | | X | X | X | X | X
Gatekeeper | X | X | X | X | X | X | X
Open Policy Agent | X | X | X | X | X | X | X
Prometheus & Grafana | X | X | X | X | X | X | X
Starboard | X | X | X | X | X | X | X
Cilium | X | | X | X | X | X | X
Kubescape | X | | X | X | X | X | X
Harbor | X (2) | | | | | |

*Local* means, the cluster will run on the machine you're working on.

*Cloud* means, that the cluster is a cloud managed cluster using the named service.

*(1)* Depending on the Kernel in use. Currently the kernels 4.15.x and 5.4.x are supported.

*(2)* Currently in beta.

## Prepare your Environment

In the following chapters I'm describing on how to prepare for the Playground in various environments. Choose one and proceed afterwards with section [Get the Playground](#get-the-playground).

### Ubuntu with built in Cluster

Follow this chapter if...

- you're using the Playground on a Ubuntu machine and
- are going to use the built in cluster.

> The cluster will get it's own docker network which is configured as follows:
>
> Config | Value
> ------ | -----
> Name | kind
> Driver | Bridge
> Subnet | 172.250.0.0/16
> IP-Range | 172.250.255.0/24
> Gateway | 172.250.255.254
>
> The `up.sh` script will create the cluster and deploy a load balancer amongst other cluster components later on. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `172.250.255.1-172.250.255.250`.  
> If the registry is deployed it will get an IP assigned by the load blancer. To allow access to the registry from your host, please configure your docker daemon to accept insecure registries and specified ip addresses.  
> To do this, create or modify `/etc/docker/daemon.json` to include a small subset of probable ips for the registry.
>
> ```sh
> sudo vi /etc/docker/daemon.json
> ```
>
> ```json
> {
>   "insecure-registries": [
>     "172.250.255.1",
>     "172.250.255.2",
>     "172.250.255.3",
>     "172.250.255.4",
>     "172.250.255.5"
>     "172.250.255.1:5000",
>     "172.250.255.2:5000",
>     "172.250.255.3:5000",
>     "172.250.255.4:5000",
>     "172.250.255.5:5000"
>   ]
> }
> ```
>
> Finally restart the docker daemon.
>
> ```sh
> sudo systemctl restart docker
> ```
>
> Since the network configuration is fixed, you don't need to do the configuration from above the next time you deploy a local cluster using the playground.

### MacOS with built in Cluster

Follow this chapter if...

- you're using the Playground on a MacOS environment with
- Docker Desktop for Mac and
- are going to use the built in cluster

> Go to the `Preferences` of Docker for Mac, then `Resources` and `Advanced`. Ensure to have at least 4 CPUs and 12+ GB of Memory assigned to Docker. (This is not required when using the public clouds.)
> 
> Due to the fact, that there is no `docker0` bridge on MacOS, we need to use ingresses to enable access to services running on our cluster. To make this work, you need to modify your local `hosts`-file.
>
> ```sh
> sudo vi /etc/hosts
> ```
>
> Change the line for `127.0.0.1` from
>
> ```txt
> 127.0.0.1 localhost
> ```
>
> to
>
> ```txt
> 127.0.0.1 localhost playground-registry smartcheck grafana prometheus
> ```

### Cloud9 with built in Cluster

Follow this chapter if...

- you're using the Playground on a AWS Cloud9 environment and
- are going to use the built in cluster

> Follow the steps below to create a Cloud9 suitable for the Playground.
>
> - Point your browser to AWS
> - Choose your default AWS region in the top right
> - Go to the Cloud9 service
> - Select `[Create Cloud9 environment]`
> - Name it as you like
> - Choose `[t3.xlarge]` for instance type and
> - `Ubuntu 18.04 LTS` as the platform
> - For the rest take all default values and click `[Create environment]`
>
> Install the latest version of the AWS CLI v2
>
> ```sh
> curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
>   -o "/tmp/awscliv2.zip"
> unzip /tmp/awscliv2.zip -d /tmp
> sudo /tmp/aws/install
> ```

### Ubuntu or MacOS with Managed Cluster

Follow this chapter if...

- you're using the Playground on a Ubuntu machine and
- are going to use either EKS, AKS or GKE

> The only preparation needed is to have an authenticated CLI for the chosen cloud provider.

### Cloud9 with AWS EKS Managed Cluster

Follow this chapter if...

- you're using the Playground on a AWS Cloud9 environment and
- are going to use EKS as the cluster

> Follow the steps below to create a Cloud9 suitable for the Playground with EKS
>
> - Point your browser to AWS
> - Choose your default AWS region in the top right
> - Go to the Cloud9 service
> - Select `[Create Cloud9 environment]`
> - Name it as you like
> - Choose `[t3.medium]` for instance type and
> - `Ubuntu 18.04 LTS` as the platform
> - For the rest take all default values and click `[Create environment]`
>
> Install the version 2.6.1 of the AWS CLI v2
>
> ```sh
> #curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
> #  -o "/tmp/awscliv2.zip"
> curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.6.1.zip" \
>   -o "awscliv2.zip"
> unzip /tmp/awscliv2.zip -d /tmp
> sudo /tmp/aws/install
> ```
>
> Update IAM Settings for the Workspace
>
> - Click the gear icon (in top right corner), or click to open a new tab and choose `[Open Preferences]`
> - Select AWS SETTINGS
> - Turn off `[AWS managed temporary credentials]`
> - Close the Preferences tab
>
> To create an IAM role which we want to attach to our Cloud9 instance, we need temporarily ***administrative privileges*** in our current shell. To get these, we need to configure our `aws` cli with our AWS credentials and the current region. Directly after assigning the created role to the instance, we're removing the credentials from the environment, of course.
>
> ```sh
> aws configure
> ```
>
> In this example I'm using `eu-central-1`. Change it to your current AWS region.
>
> ```sh
> AWS Access Key ID [None]: <KEY>
> AWS Secret Access Key [None]: <SECRET>
> Default region name [None]: eu-central-1
> Default output format [None]: json
> ```
>
> Now, run the following script, which creates and assigns the required instance role to your Cloud9 instance.
>
> ```sh
> REPO=https://raw.githubusercontent.com/mawinkler/c1-playground/master
> sudo apt install -y jq && \
>   curl -L ${REPO}/tools/cloud9-instance-role.sh | bash
> ```
>
> Use the GetCallerIdentity CLI command to validate that the Cloud9 IDE is using the correct IAM role.
>
> ```sh
> aws sts get-caller-identity --query Arn | \
>   grep ekscluster-admin -q && \
>   echo "IAM role valid" || echo "IAM role NOT valid"
> ```
>
> Finally, resize the virtual disk of your Cloud9 by running
>
> ```sh
> curl -L ${REPO}/tools/cloud9-resize.sh | bash
> ```

## Get the Playground

Clone the repo and install required packages if not available.

```sh
git clone https://github.com/mawinkler/c1-playground.git
cd c1-playground
```

In all of these possible environments you're going to run a script called `tools.sh` either on the host running the playground cluster or the host running the CLI tools of the public clouds. This will ensure you have the latest versions of

- `brew` (MacOS only),
- `docker` or `Docker for Mac`.
- `kubectl`,
- `kustomize`,
- `helm`,
- `kind`,
- `krew`,
- `stern` and
- `kubebox`

installed.

> ***Note:*** as of 05/05/2022 there is a bug in combination of ths aws-cli and `kubectl` in version 1.24.0. The reason is that Kubernetes deprecated `client.authentication.k8s.io/v1alpha1` from the `exec` plugin in [PR108616](https://github.com/kubernetes/kubernetes/pull/108616). For this reason, the `kubectl` version is currently fixed to 1.23.6-00 in the `tools.sh`-script.  
>
> If you accidentally installed `kubectl` version 1.24.0, simply downgrade it by running  
> `sudo apt-get install -y --allow-downgrades kubectl=1.23.6-00`.

> ***Note:*** as of 05/06/2022 there is a bug in the `eksctl` version 0.96.0. If you accidentally installed a newer `eksctl` version as 0.95.0 you need to downgrade eksctl to 0.95.0. Execute:
>
> ```sh
> curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/v0.95.0/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
> sudo mv /tmp/eksctl /usr/local/bin
> ```
>
> Then, recreate the eks cluster with `rapid-eks-down.sh` followed by `clusters/rapid-eks.sh`

Run it with

```sh
./tools.sh
```

## Configure

Now, you create your personal configuration file. Do this by making a copy of the supplied sample.

```sh
cp config.json.sample config.json
```

Typically you don't need to change anything here besides setting your api-key and region for Cloud One. If you intent to run multiple clusters (e.g. a local and a GKE), adapt the `cluster_name` and the `policy_name`.

```json
{
    "cluster_name": "playground",
    "services": [
...
        {
            "name": "container_security",
            "policy_name": "relaxed_playground",
            "namespace": "trendmicro-system"
        },
...
        {
            "name": "cloudone",
            "region": "YOUR CLOUD ONE REGION HERE",
            "api_key": "YOUR CLOUD ONE API KEY HERE"
        }
    ]
}
```

## Start

If you want to deploy the built-in cluster go through the next chapter. If you want to use a cloud managed cluster jump to [Create GKE, EKS or AKS Clusters](#create-gke-eks-or-aks-clusters).

### Create Playgrounds built-in Cluster

Simply run

```sh
# Local built-in Cluster
./up.sh
```

Typically, you want to deploy the cluster registry next. Do this by running

```sh
./deploy-registry.sh
```

You can find the authentication instructions within the file `services`.

Now, head over to [Deployments](#deployments).

### Create GKE, EKS or AKS Clusters

Run one of the following scripts to quickly create a cluster in the clouds.

```sh
# GKE
./clusters/rapid-gke.sh

# AKS
./clusters/rapid-aks.sh

# EKS
./clusters/rapid-eks.sh
```

You don't need to create a registry here since you're going to use the cloud provided registries GCR, ACR or ECR.

## Deployments

The playground provides a couple of scripts which deploy preconfigured versions of several products. This includes currently:

- Container Security (`./deploy-container-security.sh`)
- Smart Check (`./deploy-smartcheck.sh`)
- Prometheus & Grafana (`./deploy-prometheus.sh`)
- Starboard (`./deploy-starboard.sh`)
- Falco Runtime Security (`./deploy-falco.sh`)
- Open Policy Agent (`./deploy-opa.sh`)
- Gatekeeper (`./deploy-gatekeeper`)

## Tear Down

### Tear Down Ubuntu Local, MacOS Local or Cloud9 Local Clusters

```sh
./down.sh
```

### Tear Down GKE, EKS or AKS Clusters

Run one of the following scripts to quickly tear down a cluster in the clouds. These scripts are created automatically by the cluster scripts.

```sh
# GKE
./rapid-gke-down.sh

# AKS
./rapid-aks-down.sh

# EKS
./rapid-eks-down.sh
```

## Add-Ons

The documentation for the add-ons are located inside the `./docs` directory.

- [Cilium](docs/add-on-cilium.md)
- [Container Security](docs/add-on-container-security.md)
- [Falco](docs/add-on-falco.md)
- [Gatekeeper](docs/add-on-gatekeeper.md)
- [Harbor](docs/add-on-harbor.md)
- [Istio](docs/add-on-istio.md)
- [Krew](docs/add-on-krew.md)
- [Kubescape](docs/add-on-kubescape.md)
- [Open Policy Agent](docs/add-on-opa.md)
- [Prometheus & Grafana](docs/add-on-prometheus-grafana.md)
- [Registry](docs/add-on-registry.md)
- [Starboard](docs/add-on-starboard.md)

## Play with the Playground

If you wanna play within the playground and you're running it either on Linux or Cloud9, follow the lab guide [Play with the Playground (on Linux & Cloud9)](docs/play-on-linux.md).

If you're running the playground on MacOS, follow the lab guide [Play with the Playground (on MacOS)](docs/play-on-macos.md).

Both guides are basically identical, but since access to some services is different on Linux and MacOS there are two guides available.

Lastly, there is a [guide](docs/play-with-falco.md) to experiment with the runtime rules built into the playground to play with Falco. The rule set of the playground is located [here](falco/playground_rules.yaml).

## Demo Scripts

The Playground supports automated scripts to demonstrate functionalies of deployments. Currently, there are two scripts available showing some capabilities of Cloud One Container Security.

To run them, ensure to have an EKS cluster up and running and have Smart Check and Container Security deployed.

After configuring the policy and rule set as shown below, you can run the demos with

```sh
# Deployment Control Demo
./demos/demo-c1cs-dc.sh

# Runtime Security Demo
./demos/demo-c1cs-rt.sh
```

### Deployment Control Demo

> ***Storyline:*** A developer wants to try out a new `nginx` image but fails since the image has critical vulnerabilities, he tries to deploy from docker hub etc. Lastly he tries to attach to the pod, which is prevented by Container Security.

To prepare for the demo verify that the cluster policy is set as shown below:

- Pod properties
  - uncheck - containers that run as root
  - Block - containers that run in the host network namespace
  - Block - containers that run in the host IPC namespace
  - Block - containers that run in the host PID namespace
- Container properties
  - Block - containers that are permitted to run as root
  - Block - privileged containers
  - Block - containers with privilege escalation rights
  - Block - containers that can write to the root filesystem
- Image properties
  - Block - images from registries with names that DO NOT EQUAL REGISTRY:PORT
  - uncheck - images with names that
  - Log - images with tags that EQUAL latest
  - uncheck - images with image paths that
- Scan Results
  - Block - images that are not scanned
  - Block - images with malware
  - Log - images with content findings whose severity is CRITICAL OR HIGHER
  - Log - images with checklists whose severity is CRITICAL OR HIGHER
  - Log - images with vulnerabilities whose severity is CRITICAL OR HIGHER
  - Block - images with vulnerabilities whose CVSS attack vector is NETWORK and whose severity is HIGH OR HIGHER
  - Block - images with vulnerabilities whose CVSS attack complexity is LOW and whose severity is HIGH OR HIGHER
  - Block - images with vulnerabilities whose CVSS availability impact is HIGH and whose severity is HIGH OR HIGHER
  - Log - images with a negative PCI-DSS checklist result with severity CRITICAL OR HIGHER
- Kubectl Access
  - Block - attempts to execute in/attach to a container
  - Log - attempts to establish port-forward on a container

Most of it should already configured by the `deploy-container-security.sh` script.

Run the demo with

```sh
./demos/demo-c1cs-dc.sh
```

### Runtime Security Demo

> ***Storyline:*** A kubernetes admin newbie executes some information gathering about the kubernetes cluster from within a running pod. Finally, he gets kicked by Container Security because of the `kubectl` usage.

To successfully run the runtime demo you need adjust the aboves policy slightly.

Change:

- Kubectl Access
  - Log - attempts to execute in/attach to a container

- Exceptions
  - Allow images with paths that equal `docker.io/mawinkler/ubuntu:latest`

Additionally, set the runtime rule `(T1543)Launch Package Management Process in Container` to ***Log***. Normally you'll find that rule in the `*_error` ruleset.

Run the demo with

```sh
./demos/demo-c1cs-rt.sh
```

The demo starts locally on your system, but creates a pod in the `default` namespace of your cluster using a slightly pimped ubuntu image which is pulled from my docker hub account. The main demo runs within that pod on the cluster, not on your local machine.

The Dockerfile for this image is in `./demos/pod/Dockerfile` for you to verify, but you do not need to build it yourself.

## Experimenting

Working with Kubernetes is likely to raise the one or the other challenge.

### Migrate

This tries to solve the challenge to migrate workload of an existing cluster using public image registries to a trusted, private one (without breaking the services).

To try it, being in the playground directory run

```sh
migrate/save-cluster.sh
```

This scripts dumps the full cluster to json files separated by namespace. The namespaces `kube-system`, `registry` and `default` are currently excluded.

Effectively, this is a **backup** of your cluster including ConfigMaps and Secrets etc. which you can deploy on a different cluster easily (`kubectl create -f xxx.json`)

To migrate the images currently in use run

```sh
migrate/migrate-images.sh
```

This second script updates the saved manifests in regards the image location to point them to the private registry. If the image has a digest within it's name it is stripped.

The image get's then pulled from the public repo and pushed to the internal one. This is followed by an image scan and the redeployment.

> Note: at the time of writing the only supported private registry is the internal one.

## Testing the Playground

The Playground uses [Bats](https://github.com/sstephenson/bats) for unit testing.

Install Bats with

```sh
# Linux
npm install -g bats

# MacOS
brew install bats
```

Unit tests are in `./tests`.

To run a full tests for a cluster type simply run

```sh
# Local Kind cluster
./test-kind-linux.sh

# GKE
./test-gke.sh

# AKS
./test-aks.sh

# EKS
./test-eks.sh
```

while being in the playground directory. Make sure, that you're authenticated on AWS, GCP and / or Azure beforehand.

The following playground modules will be executed:

```
└── Build Cluster
    ├── (Registry)
    ├── Falco
    ├── Smart Check
    ├── Smart Check Scan
    ├── Container Security
    └── Destroy cluster
```

## TODO

- ...
