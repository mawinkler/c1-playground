# Getting Started with the built in Cluster

- [Getting Started with the built in Cluster](#getting-started-with-the-built-in-cluster)
  - [Choose the platform documentation](#choose-the-platform-documentation)
    - [Ubuntu](#ubuntu)
    - [MacOS](#macos)
    - [Cloud9](#cloud9)

## Choose the platform documentation

- [Ubuntu](#ubuntu)
- [MacOS](#macos)
- [Cloud9](#cloud9)

### Ubuntu

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
>     "172.250.255.5",
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

### MacOS

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

### Cloud9

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
