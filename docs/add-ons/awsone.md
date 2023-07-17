- [Add-On: AWS One Playground](#add-on-aws-one-playground)
  - [Vision One XDR for Containers](#vision-one-xdr-for-containers)
  - [Vision One Endpoint Security Server \& Workload Protection](#vision-one-endpoint-security-server--workload-protection)
    - [Prepare](#prepare)
      - [Verify your `config.yaml`](#verify-your-configyaml)
      - [Optional: Adapt `terraform.tfvars`](#optional-adapt-terraformtfvars)
      - [Optional: Server \& Workload Protection Event-Based Tasks](#optional-server--workload-protection-event-based-tasks)
    - [Deploy with Terraform](#deploy-with-terraform)
    - [Access the EC2 instance(s)](#access-the-ec2-instances)
    - [Create Findings and Scan with Sentry](#create-findings-and-scan-with-sentry)
    - [Atomic Launcher](#atomic-launcher)
    - [Destroy](#destroy)


# Add-On: AWS One Playground

The AWS One Playground is a small environment in AWS and easily created with the help of Terraform.

Trend Micro Solutions currently in scope of this environment are:

- Vision One
- Vision One Endpoint Security Server & Workload Protection
- Vision One XDR for Containers
- Cloud One Sentry

## Vision One XDR for Containers

At the time of writing, XDR for Containers is in an early preview stage. Unless you already have an EKS cluster running whose VPC is connected to XDR for Containers you can create one from within the Playground menu. Choose `EKS-A  Elastic Kubernetes Cluster (Amazon Linux)` in this case. This cluster variant supports Application Load Balancing which is required for XDR for Containers.

You need to create a connection with XDR for Containers by going through the workflow in your Vision One environment.

After setting everything up, you can deploy exploitable workload (`Deploy Attackers and Victims`) via the `Hacks` submenu of the Playground.

> ***Note:*** This process will get easier with the GA release of XDR for Containers.

## Vision One Endpoint Security Server & Workload Protection

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

### Prepare

#### Verify your `config.yaml`

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
    ## The windows administrator password
    ## 
    ## Default value: "Chang3.M3!"
    windows_password: "Chang3.M3!"
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

Next, you need to download the installer packages for Vision One Endpoint Security for Windows and Linux operating systems from your Vision One instance. You need to do this manually since these installers are specific to your environment. The downloaded files should be named `TMServerAgent_Linux_auto_64_Server_-_Workload_Protection_Manager.tar` respectively `TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip` and are to be placed into the directory `./terraform-awsone/files`

Optionally, download the Atomic Launcher from [here](https://wiki.jarvis.trendmicro.com/display/GRTL/Atomic+Launcher#AtomicLauncher-DownloadAtomicLauncher) and store them in the  `./terraform-awsone/files` directory as well.

Your `files`-directory should look like this:

```sh
-rw-rw-r-- 1 17912014 May 15 09:10 atomic_launcher_linux_1.0.0.1009.zip
-rw-rw-r-- 1 96135367 May 15 09:05 atomic_launcher_windows_1.0.0.1013.zip
-rw-rw-r-- 1        0 May 23 09:30 see_documentation
-rw-rw-r-- 1 27380224 Jul 11 07:39 TMServerAgent_Linux_auto_64_Server_-_Workload_Protection_Manager.tar
-rw-rw-r-- 1      130 Jul 17 10:12 TMServerAgent_Linux_deploy.sh
-rw-r--r-- 1  3303330 Jul  4 11:10 TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip
-rw-rw-r-- 1     1102 Jul 14 14:06 TMServerAgent_Windows_deploy.ps1
```

#### Optional: Adapt `terraform.tfvars`

The `terraform.tfvars`-file allows you to configure the AWSONE playground in some aspects.

```tf
# Allow access to the environment from any location or restrict it to your public ip
# Example:
#   access_ip      = "<YOUR IP>/32"
access_ip        = "0.0.0.0/0"

# Linux Username (Do not change)
linux_username   = "ubuntu"

# Windows Username and Password
windows_username = "admin"
windows_password = "Chang3.M3!"

# Create Linux instance(s)
create_linux     = true

# Create Windows instance(s)
create_windows   = true

# AWS Account ID
account_id       = "xxxxxxxxxxxx"

# AWS Region
aws_region       = "eu-central-1"
```

#### Optional: Server & Workload Protection Event-Based Tasks

Create Event-Based Tasks to automatically assign Linux or Windows server policies to the machines.

Agent-initiated Activation Linux

- *Actions:* Assign Policy: Linux Server
- *Conditions:* "Platform" matches ".*Linux.*"

Agent-initiated Activation Windows

- *Actions:* Assign Policy: Windows Server
- *Conditions:* "Platform" matches ".*Windows.*"

### Deploy with Terraform

Now, you're ready to create your lab environment on AWS :-)

```sh
# plan configuration
terraform plan -out terraform.out

# apply configuration
terraform apply terraform.out
```

For the impatient, simply run

```sh
terraform apply -auto-approve
```

Expected output (example):

```sh
Apply complete! Resources: 26 added, 0 changed, 0 destroyed.

Outputs:

private_key_path = "playground-key-pair.pem"
public_instance_id_db1 = "i-0d79e40833c0c08e7"
public_instance_id_srv1 = "i-04c2a374d19e28f79"
public_instance_id_web1 = "i-0d083f310276959e0"
public_instance_ip_db1 = "3.74.163.217"
public_instance_ip_srv1 = "3.66.215.220"
public_instance_ip_web1 = "18.185.121.227"
s3_bucket = "playground-awsone-e6yhxjjf"
```

### Access the EC2 instance(s)

If you want to sniff around on your newly created little instances connect to it via:

```sh
# Linux web1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_web1)

# Linux db1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_db1)

# Windows srv1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no admin@$(terraform output -raw public_instance_ip_srv1)
```

To connect to the Windows Server you can also use Remote Desktop with username/password from `terraform.tfvars`. Use the configured admin user for authentication, the ip address is shown in the outputs section after `terraform apply`.

### Create Findings and Scan with Sentry

In the next step we're preparing some findings for Sentry.

```sh
scripts/create-findings.sh
```

Feel free to have a look on the script above, but in theory it should prepare six findings for Sentry and two Workbenches in Vision One.

To trigger Sentry scans for any instance run (example):

```sh
# INSTANCE=<INSTANCE_ID> sentry-trigger-ebs-scan
INSTANCE=$(terraform output -raw public_instance_ip_web1) sentry-trigger-ebs-scan
```

Output:

```sh
Using region eu-central-1 for user cnctraining
State machine is arn:aws:states:eu-central-1:634503960501:stateMachine:ScannerStateMachine-Oy8lw0b3BGHB
Instance volume(s):
vol-0bb7b80e52c694dc9
Snapshot snap-08c5010498b27e6a2 for volume vol-0bb7b80e52c694dc9 created
{
  "ScanID": "634503960501-18f0f49f-ed74-48a7-aefd-fa1556213305",
  "ResourceType": "aws-ebs-volume",
  "ResourceLocation": "snap-08c5010498b27e6a2",
  "ResourceRegion": "eu-central-1",
  "MetaData": {
    "AWSAccountID": "634503960501",
    "SnapshotID": "snap-08c5010498b27e6a2",
    "VolumeID": "vol-0bb7b80e52c694dc9",
    "AttachedInstances": [
      {
        "InstanceID": "i-0d083f310276959e0"
      }
    ]
  }
}
{
    "executionArn": "arn:aws:states:eu-central-1:634503960501:execution:ScannerStateMachine-Oy8lw0b3BGHB:aws-ebs-volume-634503960501-18f0f49f-ed74-48a7-aefd-fa1556213305-manual",
    "startDate": "2023-07-17T11:56:50.644000+00:00"
}
```

The scan results should show up in your Cloud One Central console.

### Atomic Launcher

The Atomic Launcher is stored within the downloads folder of each of the instances.

The unzip password is `virus`.

You should disable Anti Malware protection und set detect only for the IPS module before using Atomic Launcher.

### Destroy

```sh
# destroy
terraform destroy -auto-approve
```
