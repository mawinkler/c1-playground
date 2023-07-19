- [Add-On: AWS One Playground](#add-on-aws-one-playground)
  - [Architecture](#architecture)
    - [Network](#network)
    - [Virtual Instances](#virtual-instances)
    - [Kubernetes Cluster](#kubernetes-cluster)
    - [Cluster Deployments](#cluster-deployments)
  - [General Life-Cycle](#general-life-cycle)
    - [Create the Environment](#create-the-environment)
    - [Create Workload](#create-workload)
    - [Tear Down](#tear-down)
  - [Prepare](#prepare)
    - [Verify your `config.yaml`](#verify-your-configyaml)
    - [Optional: Adapt `terraform.tfvars`](#optional-adapt-terraformtfvars)
    - [Optional: Server \& Workload Protection Event-Based Tasks](#optional-server--workload-protection-event-based-tasks)
  - [Notes on the Components](#notes-on-the-components)
    - [Access the EC2 instance(s)](#access-the-ec2-instances)
    - [Access the EKS Kubernetes Cluster](#access-the-eks-kubernetes-cluster)
    - [Vision One XDR for Containers](#vision-one-xdr-for-containers)
    - [Vision One Endpoint Security Server \& Workload Protection](#vision-one-endpoint-security-server--workload-protection)
    - [Sentry](#sentry)
    - [Atomic Launcher](#atomic-launcher)


# Add-On: AWS One Playground

The AWS One Playground is a small environment in AWS and easily created with the help of Terraform.

Trend Micro Solutions currently in scope of this environment are:

- Vision One
- Vision One Endpoint Security Server & Workload Protection
- Vision One XDR for Containers
- Vision One Container Security
- Cloud One Sentry

and

- Most Add-ons of the "traditional" Playground Simplicity

## Architecture

AWS One utilizeses Terraform to maintain the environment. For best flexibility and Cost Optimization it is structured into several Terraform configurations which I'm going to explain in the next chapters:

### Network

Configuration located in `2-network`

This creates a VPC with the most commonly used architecture, private and public subnets accross three availability zones. It includes everything what a VPC should have, this is amongst others an internet gateway, NAT gateway, security groups, etc. Since a VPC is cheap there's no real need to destroy the networking configuration everyday, just leave it as it is and reuse it the next time. This eases the handling of other components like Vision One XDR for Containers.

### Virtual Instances

Configuration located in `3-instances`

Depends on `2-network`

Basically, a couple of EC2 instances are created with this configuration. Currently these are two Linux and one Windows instance.

If you store the agent installers for Server and Workload Security in `0-files` the instances will connect to Vision One.

You can optionally drop any file or installer in the `0-files` directory which will then be available in the ec2 instances download folder.

### Kubernetes Cluster

Configuration located in `4-cluster`

Depends on `2-network`

So, this is my favorit part. This configuration creates an EKS cluster with some nice key features:

- Autoscaling from 1 to 10 nodes
- Nodes running as Spot instances to save money :-)
- ALB Load Balancer controller
- Located in the private subnets

### Cluster Deployments

Configuration located in `9-cluster-deployments`

Depends on `4-cluster`

TODO

## General Life-Cycle

### Create the Environment

Start with `2-network`

```sh
cd 2-network

# automatically download terraform modules
terraform init

# plan configuration
terraform plan -out terraform.out

# apply configuration
terraform apply terraform.out
```

For the impatient, simply run

```sh
cd 2-network
terraform init
terraform apply -auto-approve
```

This will create your VPC in the configured region (see `config.yaml`)

### Create Workload

If you want to use EC2 instances:

```sh
cd 3-instances
terraform init
terraform apply -auto-approve
```

If you want to use the EKS cluster:

```sh
cd 4-cluster
terraform init
terraform apply -auto-approve
```

You can choose to use either or both, of course.

When using the EKS cluster, some cluster deployments might make sense:

```sh
cd 9-cluster-deployments
terraform init
terraform apply -auto-approve
```

### Tear Down

If you want to destroy your environment...

...simply run

```sh
terraform destroy -auto-approve
```

in the directories `3-`, `4-`, or `9-`. If you really want to tear down everything, destroy the network `2-` as the last step.

## Prepare

If running on a local Linux server run

```sh
aws configure
```

This is not needed for Cloud9 environments.

### Verify your `config.yaml`

Your `config.yaml` needs to set the following variables (see `config.yaml.sample`):

```yaml
  - name: aws
    ## The account id of your AWS account
    ## 
    ## Default value: ''
    account_id: ''

    ## The default AWS region to use
    ## 
    ## Default value: "eu-central-1"
    region: "eu-central-1"

  - name: awsone
    ## Restrict access to AWS One
    ## 
    ## Default value: "0.0.0.0/0"
    access_ip: "0.0.0.0/0"

    ## Create Linux instance(s)
    ## 
    ## Default value: true
    create_linux: true

    ## Create Windows instance(s)
    ## 
    ## Default value: true
    create_windows: true
```

Ensure the latest AWS CLI via the Playground menu `Tools --> CLIs --> AWS` and to have authenticated via `aws configure`.

To prepare AWS One Playground demo environmant run

```sh
deploy-awsone.sh
```

and exit the Playground menu. Change in the terraform subdirectory

```sh
cd $PGPATH/terraform-awsone
```

Next, you need to download the installer packages for Vision One Endpoint Security for Windows and Linux operating systems from your Vision One instance. You need to do this manually since these installers are specific to your environment. The downloaded files should be named `TMServerAgent_Linux_auto_64_Server_-_Workload_Protection_Manager.tar` respectively `TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip` and are to be placed into the directory `./terraform-awsone/0-files`

Optionally, download the Atomic Launcher from [here](https://wiki.jarvis.trendmicro.com/display/GRTL/Atomic+Launcher#AtomicLauncher-DownloadAtomicLauncher) and store them in the  `./terraform-awsone/0-files` directory as well.

Your `0-files`-directory should look like this:

```sh
-rw-rw-r-- 1 17912014 May 15 09:10 atomic_launcher_linux_1.0.0.1009.zip
-rw-rw-r-- 1 96135367 May 15 09:05 atomic_launcher_windows_1.0.0.1013.zip
-rw-rw-r-- 1        0 May 23 09:30 see_documentation
-rw-rw-r-- 1 27380224 Jul 11 07:39 TMServerAgent_Linux_auto_64_Server_-_Workload_Protection_Manager.tar
-rw-rw-r-- 1      130 Jul 17 10:12 TMServerAgent_Linux_deploy.sh
-rw-r--r-- 1  3303330 Jul  4 11:10 TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip
-rw-rw-r-- 1     1102 Jul 14 14:06 TMServerAgent_Windows_deploy.ps1
```

### Optional: Adapt `terraform.tfvars`

The `terraform.tfvars`-file allows you to configure the AWSONE playground configurations in some aspects.

```tf
# Allow access to the environment from any location or restrict it to your public ip
# Example:
#   access_ip      = "<YOUR IP>/32"
access_ip        = "0.0.0.0/0"

# Linux Username (Do not change)
linux_username   = "ubuntu"

# Windows Username
windows_username = "admin"

# Create Linux instance(s)
create_linux     = true

# Create Windows instance(s)
create_windows   = true

# AWS Account ID
account_id       = "xxxxxxxxxxxx"

# AWS Region
aws_region       = "eu-central-1"
```

### Optional: Server & Workload Protection Event-Based Tasks

Create Event-Based Tasks to automatically assign Linux or Windows server policies to the machines.

Agent-initiated Activation Linux

- *Actions:* Assign Policy: Linux Server
- *Conditions:* "Platform" matches ".*Linux.*"

Agent-initiated Activation Windows

- *Actions:* Assign Policy: Windows Server
- *Conditions:* "Platform" matches ".*Windows.*"

## Notes on the Components

### Access the EC2 instance(s)

Requirement: You applied the configuration `3-instances`.

If you want to play with the instances you can connect to them via:

```sh
# Linux web1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_web1)

# Linux db1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_db1)

# Windows srv1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no admin@$(terraform output -raw public_instance_ip_srv1)
```

To connect to the Windows Server you can also use Remote Desktop. Use the configured `admin` user for authentication, the ip address is shown in the outputs section after `terraform apply`. Retrieve the password with

```sh
terraform output -raw public_instance_password_srv1
```

### Access the EKS Kubernetes Cluster

Requirement: You applied the configuration `4-cluster`.

### Vision One XDR for Containers

At the time of writing, XDR for Containers is in an early preview stage. Unless you already have an EKS cluster running whose VPC is connected to XDR for Containers you can create one from within the Playground menu. Choose `EKS-A  Elastic Kubernetes Cluster (Amazon Linux)` in this case. This cluster variant supports Application Load Balancing which is required for XDR for Containers.

You need to create a connection with XDR for Containers by going through the workflow in your Vision One environment.

> ***Note:*** This process will get easier with the GA release of XDR for Containers.

### Vision One Endpoint Security Server & Workload Protection

Three different instances are currently provided by the AWS One Playground with different configurations:

Instance Web1:

- Ubuntu Linux 20.04
- Nginx and Wordpress deployment
- Vision One Endpoint Security Basecamp agent for Server & Workload Protection

Instance Db1:

- Ubuntu Linux 20.04
- MySql databse
- Vision One Endpoint Security Basecamp agent for Server & Workload Protection

Instance Srv1:

- Windows Server 2022 Standalone Server
- Vision One Endpoint Security Basecamp agent for Server & Workload Protection

All instances are integrated with Vision One Endpoint Security for Server & Workload Protection and have access to the Attomic Launcher.

The instances are created within a public subnet of an automatically created VPC. They all get an EC2 instance role assigned providing them the ability to access installer packages stored within an S3 bucket.

All instances including the Windows Server are accessible via ssh and key authentication. RDP for Windows is supported as well.

### Sentry

To create findings and scan with Sentry run

```sh
1-scripts/create-findings.sh
```

Feel free to have a look on the script above, but in theory it should prepare six findings for Sentry and two Workbenches in Vision One.

To trigger Sentry scans for any instance run (example):

```sh
# INSTANCE=<INSTANCE_ID> sentry-trigger-ebs-scan
INSTANCE=$(terraform output -raw public_instance_ip_web1) sentry-trigger-ebs-scan
```

The scan results should show up in your Cloud One Central console.

### Atomic Launcher

The Atomic Launcher is stored within the downloads folder of each of the instances.

The unzip password is `virus`.

You should disable Anti Malware protection und set detect only for the IPS module before using Atomic Launcher.
