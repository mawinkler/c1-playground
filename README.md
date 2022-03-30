# Playground

- [Playground](#playground)
  - [Requirements and Support Matrix](#requirements-and-support-matrix)
    - [Supported Cluster Variants](#supported-cluster-variants)
    - [Suport Matrix](#suport-matrix)
  - [Tools](#tools)
  - [Configure](#configure)
  - [Start](#start)
    - [Create Ubuntu Local, MacOS Local or Cloud9 Local Clousters](#create-ubuntu-local-macos-local-or-cloud9-local-clousters)
    - [Create GKE, EKS or AKS Clusters](#create-gke-eks-or-aks-clusters)
  - [Deployments](#deployments)
  - [Tear Down](#tear-down)
    - [Tear Down Ubuntu Local, MacOS Local or Cloud9 Local Clusters](#tear-down-ubuntu-local-macos-local-or-cloud9-local-clusters)
    - [Tear Down GKE, EKS or AKS Clusters](#tear-down-gke-eks-or-aks-clusters)
  - [Add-Ons](#add-ons)
  - [Play with the Playground](#play-with-the-playground)
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
> The deployment scripts are supporting the following managed cluster types:
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
C1CS Runtime Security | | | | X | X | X
Falco | X | | X | X | X | X | X
Gatekeeper | X | X | X | X | X | X | X
Open Policy Agent | X | X | X | X | X | X | X
Prometheus & Grafana | X | X | X | X | X | X | X
Starboard | X | X | X | X | X | X | X

*Local* means, the cluster will run on the machine you're working on.

*Cloud* means, that the cluster is a cloud services cluster using the named service.

## Tools

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

> ***MacOS Local:***
>
> If running the playground locally with Docker for Mac, go to the `Preferences` of Docker for Mac, then `Resources` and `Advanced`. Ensure to have at least 4 CPUs and 12+ GB of Memory assigned to Docker. This is not required when using the public clouds.
>
> ***Cloud9 Local:***
>
> - Select Create Cloud9 environment
> - Give it a name
> - Choose “t3.xlarge” or better for instance type and
> - Ubuntu Server 18.04 LTS as the platform.
> - For the rest take all default values and click Create environment

Clone the repo and install required packages if not available.

```sh
git clone https://github.com/mawinkler/c1-playground.git
cd c1-playground
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
            "namespace": "container-security"
        },
...
        {
            "name": "cloudone",
            "region": "YOUR REGION HERE",
            "api_key": "YOUR KEY HERE"
        }
    ]
}
```

> ***Ubuntu Local:***
>
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
> The `up.sh` script will deploy a load balancer amongst other cluster components later on. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `172.250.255.1-172.250.255.250`.  
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
>
> ***MacOS Local:***
>
> Due to the fact, that there is no `docker0` bridge on MacOS, we need to use ingresses to enable access to services running on our cluster. To make this work, you need to modify your local `hosts`-file.
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
>
> ***Cloud9 Local:***
>
> You now need to resize the disk of the EC2 instance to 30GB, execute:
>
> ```sh
> ./tools/cloud9-resize.sh
> ```

## Start

### Create Ubuntu Local, MacOS Local or Cloud9 Local Clousters

Simply run

```sh
./up.sh
```

Typically, you want to deploy the cluster registry next. Do this by running

```sh
./deploy-registry.sh
```

You can find the authentication instructions within the file `services`.

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

Run one of the following scripts to quickly create a cluster in the clouds.

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

- [Registry](docs/add-on-registry.md)
- [Container Security](docs/add-on-container-security.md)
- [Prometheus & Grafana](docs/add-on-prometheus-grafana.md)
- [Falco](docs/add-on-falco.md)
- [Krew](docs/add-on-krew.md)
- [Starboard](docs/add-on-starboard.md)
- [Open Policy Agent](docs/add-on-opa.md)
- [Gatekeeper](docs/add-on-gatekeeper.md)

## Play with the Playground

If you wanna play within the playground and you're running it either on Linux or Cloud9, follow the lab guide [Play with the Playground (on Linux & Cloud9)](docs/play-on-linux.md).

If you're running the playground on MacOS, follow the lab guide [Play with the Playground (on MacOS)](docs/play-on-macos.md).

Both guides are basically identical, but since access to some services is different on Linux and MacOS there are two guides available.

Lastly, there is a [guide](docs/play-with-falco.md) to experiment with the runtime rules built into the playground to play with Falco. The rule set of the playground is located [here](falco/playground_rules.yaml).

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
