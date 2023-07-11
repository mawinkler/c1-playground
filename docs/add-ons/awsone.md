# Add-On: AWS One Playground

The AWS One Playground is a small environment in AWS and easily created with the help of Terraform.

Trend Micro Solutions currently in scope of this environment are:

- Vision One
- Cloud One Workload Security
- Cloud One Sentry

All instances are based on Ubuntu Focal 20.04 with different configurations:

Instance Web1:

- Ubuntu Linux 20.04
- Nginx and Wordpress deployment
- Atomic Launcher version 1.0.0.1009
- Vision One Endpoint Security Basecamp agent for Server & Workload Protection

Instance Db1:

- Ubuntu Linux 20.04
- MySql databse
- Vision One Endpoint Security Basecamp agent for Server & Workload Protection

Instance Srv1:

- Windows Server 2022
- Atomic Launcher version 1.0.0.1013
- Vision One Endpoint Security Basecamp agent for Server & Workload Protection

> ***Note:*** ***V1ES*** - You need to download the installer packages for Windows and Linux operating systems from your V1ES - Endpoint inventory app. The downloaded files should be named `TMServerAgent_Linux_auto_64_Server_-_Workload_Protection_Manager.tar` respectively `TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip` and are to be placed into the directory `./terraform-awsone/ec2/files` before deploying the environment.
>  
> ***Note:*** ***Atomic*** You need to download the Atomic Launcher from [here](https://powerbox-jarvis-file.trendmicro-cloud.com/SFDC/DownloadFile_iv_jarvis.php?Query=qFFk%2B1MYPMLKEci1xi14KCgv1vM3eXaXOauUOhpMNNvwnxQddJMSFOHKNsbQ9F2LoIFZHLssJibE2BTXUIDXKiZQF0H4L%2FTjVNji9DGALMQk0P9PFprMO2gOpJgGjlRqIIbkBV3SGTjY4DJVqGqoEQ%3D%3D&iv=ZDSEnjIt0ZefLf74) and store it in the `./terraform-awsone/files`-directory. You do *NOT* need to unzip the file.

## Prepare

Ensure the latest AWS CLI via the Playground menu `Tools --> CLIs --> AWS` and to have authenticated via `aws configure`.

To prepare AWS One Playground demo environmant run

```sh
deploy-awsone.sh
```

and exit the Playground menu. Change in the terraform subdirectory

```sh
cd $PGPATH/terraform-awsone
```

### Optional: Adapt `variables.tf`

The `variables.tf`-file contains the definitions for the AWS region. Adapt it to your needs as required.

If you are working on a shared environment you likely want to change `private_key_path` and `public_key_path` to make it unique in your environment.

```json
variable "aws_region" {
  default = "eu-central-1"
}
...
```

### Optional: Adapt `terraform.tfvars`

The `terraform.tfvars`-file allows you to restrict internet access to your EC2 instances to only your public IP address. For this you need to change

```tf
access_ip      = "0.0.0.0/0"
```

to 

```json
access_ip      = "<YOUR IP>/32"
```

The Windows Server get's a local administrator provisioned. Username and password are configured by default to

```tf
windows_username = "winadmin1"

windows_password = "Chang3.M3!"
```

## Deploy with Terraform

Prepare your terraform environment by running

```sh
# init modules
terraform init

# validate configuration
terraform validate
```

Now, you're ready to create your lab environment on AWS :-)

```sh
# plan configuration
terraform plan -out terraform.out

# apply configuration
terraform apply terraform.out
```

For the impatient, simply run

```sh
terraform apply --auto-approve
```

## Access the EC2 instance(s)

If you want to sniff around on your newly created little instances connect to it via:

```sh
# Linux web1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_web1)

# Linux db1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_db1)
```

To connect to the `srv1` use Remote Desktop with username/password from `terraform.tfvars`.

## Optional: Sserver & Workload Protection

Create Event-Based Tasks to automatically assign Linux or Windows server policies to the machines.

Agent-initiated Activation Linux

- Actions:
  - Assign Policy: Linux Server
- Conditions:
  - "Platform" matches ".*Linux.*"

Agent-initiated Activation Windows

- Actions:
  - Assign Policy: Windows Server
- Conditions:
  - "Platform" matches ".*Windows.*"

## Create Findings

In the next step we're preparing some findings for Sentry.

```sh
scripts/create-findings.sh
```

Feel free to have a look on the script above, but in theory it should prepare six findings.

## AtomicRed

The Windows Server `srv1` and the Linux Server `web1` have the Atomic Launcher available. On `web1` it's located in the home directory of the user, on `srv1` its within `C:\Windows\Temp`.

Unzip password is `virus`.

## Detroy

```sh
# destroy
terraform destroy
```
