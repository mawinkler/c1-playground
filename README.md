# Playground

- [Playground](#playground)
  - [Requirements and Support Matrix](#requirements-and-support-matrix)
    - [Cluster Variants](#cluster-variants)
    - [Suport Matrix](#suport-matrix)
  - [Tools](#tools)
  - [Configure](#configure)
  - [Start](#start)
  - [Tear Down](#tear-down)
  - [Add-Ons](#add-ons)
  - [Play with the Playground](#play-with-the-playground)

Ultra fast and slim kubernetes playground.

Currently, the following services are integrated:

- Prometheus & Grafana
- Starboard
- Falco Runtime Security including Kubernetes Auditing
- Container Security
  - Smart Check
  - Deployment Admission Control, Continuous Compliance
- Open Policy Agent
- Gatekeeper

The playground runs on local or Cloud9 based Ubuntu servers, GKE, AKS, EKS and most parts on MacOS as well.

## Requirements and Support Matrix

> Note: The Playgound is designed to work on this operating systems
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

### Cluster Variants

Originally, the playground was desigined to create a kubernetes cluster locally on the host running the playground scripts. This is still the fastest way of getting a cluster up and running.

In addition to the local cluster, it is also possible to use most functionality of the playground on the managed clusters of the main cloud providers AWS, GCP & Azure as well. Going into this direction requires you to work on a Linux / MacOS shell and an authenticated CLI to the chosen cloud provider (`aws`, `az` or `gcloud`).

Before or after you've authenticated to the cloud, be sure to install the required tools as described in the next section.

> Using managed clusters with the playground scripts is not 100% tested, so some things might not work as expected. If you find a bug, please raise an issue.

Within the directory `clusters` are scripts to rapidly create a kubernetes cluster on the three major public clouds. This comes in handy, if you want to play on these public clouds or have no possibility to run an Ubuntu or MacOS. Do not run `up.sh` or `down.sh` when using these clusters.

### Suport Matrix

Add-On | Ubuntu | Cloud9 | MacOS | GKE | EKS | AKS
------ | ------ | ------ | ----- | --- | --- | ---
Registry | X | X | X | | |
Scanning Scripts | X | X | X | X | | X
C1CS Admission & Continuous | X | X | X | X | X | X
C1CS Runtime Security | | | | X | X | X
Falco | X | X | | X | X | X | X
Gatekeeper | X | X | X | X | X | X | X
Open Policy Agent | X | X | X | X | X | X | X
Prometheus & Grafana | X | X | X | X | X | X | X
Starboard | X | X | X | X | X | X | X

## Tools

In all of these possible environments you're going to run a script called `tools.sh` either on the host running the playground cluster or the host running the CLI tools of the public clouds. This will ensure you have the latest versions of

- `brew` (MacOS only),
- `docker` or `Docker for Mac`.
- `kubectl`,
- `kustomize`,
- `helm`,
- `kind`,
- `krew` and
- `kubebox`

installed.

Follow the steps for your platform below and continue afterwards in a new shell.

***Linux***

Download the repo and install required packages if not available.

```sh
$ git clone https://github.com/mawinkler/c1-playground.git
$ cd c1-playground
$ ./tools.sh
```

***MacOS***

Download the repo and install required packages if not available.

```sh
$ git clone https://github.com/mawinkler/c1-playground.git
$ cd c1-playground
$ ./tools.sh
```

If running the playground locally, go to the `Preferences` of Docker for Mac, then `Resources` and `Advanced`. Ensure to have at least 4 CPUs and 12+ GB of Memory assigned to Docker. This is not required when using the public clouds.

***Cloud9***

- Select Create Cloud9 environment
- Give it a name
- Choose “t3.xlarge” or better for instance type and
- Ubuntu Server 18.04 LTS as the platform.
- For the rest take all default values and click Create environment

When it comes up, customize the environment by closing the welcome tab and lower work area, and opening a new terminal tab in the main work area.

Download the repo and install required packages if not available.

```sh
$ git clone https://github.com/mawinkler/c1-playground.git
$ cd c1-playground
$ ./tools.sh
```

## Configure

First step is to clone the repo to your machine and second you create your personal configuration file.

```sh
cp config.json.sample config.json
```

Typically you don't need to change anything here besides setting your api-key and region for Cloud One. If you're planning to use Cloud One Container Security you don't need an activation key for smart check, the api-key is then sufficient.

> ***Note:*** Please use a real Cloud One API Key, not the one from Workload Security.

```json
{
    "cluster_name": "playground",
...
    "services": [
        {
            "name": "cloudone",
            "region": "YOUR REGION HERE",
            "api_key": "YOUR KEY HERE",
        }
    ]
}
```

If you're ***not*** using the public cloud clusters, follow the steps for your platform below.

***Linux***

The `up.sh` script will deploy a load balancer amongst other cluster components later on. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `X.X.255.1-X.X.255.250`. If the registry is deployed it will very likely be the second service requesting a load balancer IP, so typically it will get the `172.18.255.2` assignend which we define as an insecure registry for our local docker daemon.

To do this, create or modify `/etc/docker/daemon.json` to include a small subset probable ips for the registry.

```sh
$ sudo vi /etc/docker/daemon.json
```

```json
{"insecure-registries": ["172.18.255.1:5000","172.18.255.2:5000","172.18.255.3:5000"]}
```

Finally restart the docker daemon.

```sh
$ sudo systemctl restart docker
```

In the following step [Start](#start), you'll create the cluster, typically followed by creating the cluster registry. The last line of the output from `./deploy-registry.sh` shows you a docker login example. Try this. If it fails you need to verify the IP address range of the integrated load balancer that it matches the IPs from above. Typically, this is not required.

If it failed, we need to determine the network that is being used for the node ip pool. For that, we need to run `up.sh` and then query the nodes.

```sh
$ kubectl get nodes -o json | jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address'
```

```
172.18.0.2
```

Adapt the file `/etc/docker/daemon.json` accordingly. Then

```sh
$ ./stop.sh
$ sudo systemctl restart docker
```

***MacOS***
Due to the fact, that there is no `docker0` bridge on MacOS, we need to use ingresses to enable access to services running on our cluster. To make this work, you need to modify your local `hosts`-file.

Change the line for 127.0.0.1 from

```txt
127.0.0.1 localhost
```

to

```txt
127.0.0.1 localhost playground-registry smartcheck grafana prometheus
```

***Cloud9***

You now need to resize the disk of the EC2 instance to 30GB, execute:

```sh
$ ./resize.sh
```

The `up.sh` script later on will deploy a load balancer amongst other cluster components. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `X.X.255.1-X.X.255.250`. If the registry is deployed it will very likely be the second service requesting a load balancer IP, so typically it will get the `172.18.255.2` assignend which we define as an insecure registry for our local docker daemon.

To do this, create or modify `/etc/docker/daemon.json` to include a small subset probable ips for the registry.

```sh
$ sudo vi /etc/docker/daemon.json
```

```json
{"insecure-registries": ["172.18.255.1:5000","172.18.255.2:5000","172.18.255.3:5000"]}
```

Finally restart the docker daemon.

```sh
$ sudo systemctl restart docker
```

In the following step [Start](#start), you'll create the cluster, typically followed by creating the cluster registry. The last line of the output from `./deploy-registry.sh` shows you a docker login example. Try this. If it fails you need to verify the IP address range of the integrated load balancer that it matches the IPs from above. Typically, this is not required.

If it failed, we need to determine the network that is being used for the node ip pool. For that, we need to run `up.sh` and then query the nodes.

```sh
$ kubectl get nodes -o json | jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address'
```

```
172.18.0.2
```

Adapt the file `/etc/docker/daemon.json` accordingly. Then

```sh
$ ./stop.sh
$ sudo systemctl restart docker
```

## Start

Simply run

```sh
$ ./up.sh
```

if using the playground cluster. Otherwise run one of the scripts within `clusters/`.

Typically, you want to deploy the cluster registry next. Do this by running

```sh
$ ./deploy-registry.sh
```

You can find the authentication instructions within the file `services`.

## Tear Down

```sh
$ ./down.sh
```

if using the playground cluster. Otherwise follow the instructions printed after you did run one of the scripts within `clusters/`.

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
