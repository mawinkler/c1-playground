# Add-On: AWS One Playground

The AWS One Playground is a small environment in AWS and easily created with the help of Terraform.

All instances are based on Ubuntu Focal 20.04 with different configurations:

Instance Web1:

- Nginx
- Atomic Launcher version 1.0.0.1009
- Vision One Basecamp agent

Instance Web2:

- Wordpress deployment
- Atomic Launcher version 1.0.0.1009
- Workload Security agent

Instance Db1:

- MySql databse
- Workload Security agent

> ***Note:*** You need to download the Atomic Launcher from [here](https://powerbox-jarvis-file.trendmicro-cloud.com/SFDC/DownloadFile_iv_jarvis.php?Query=qFFk%2B1MYPMLKEci1xi14KCgv1vM3eXaXOauUOhpMNNvwnxQddJMSFOHKNsbQ9F2LoIFZHLssJibE2BTXUIDXKiZQF0H4L%2FTjVNji9DGALMQk0P9PFprMO2gOpJgGjlRqIIbkBV3SGTjY4DJVqGqoEQ%3D%3D&iv=ZDSEnjIt0ZefLf74) and store it in the `./terraform-awsone/files`-directory. You do *NOT* need to unzip the file.

## Prepare

Ensure the latest AWS CLI via the Playground menu `Tools --> CLIs --> AWS` and to have authenticated via `aws configure`.

To prepare AWS One Playground demo environmant run:

```sh
deploy-awsone.sh
```

Change in the terraform subdirectory

```sh
cd $PGPATH/terraform-awsone
```

## Optional: Adapt `variables.tf`

The `variables.tf`-file contains the definitions for the AWS region and keypair to use. Adapt it to your needs as required.

If you are working on a shared environment you likely want to change `private_key_path` and `public_key_path` to make it unique in your environment.

```json
variable "aws_region" {
  default = "eu-central-1"
}

variable "public_key_path" {
  default = "cnctraining-key-pair.pub"
}

variable "private_key_path" {
  default = "cnctraining-key-pair"
}

variable "xbc_agent_url" {
    default = ""
}

variable "access_ip" {
  type = string
}
```

## Optional: Adapt `terraform.tfvars`

The `terraform.tfvars`-file allows you to restrict internet access to your EC2 instances to only your public IP address. For this you need to change

```tf
access_ip      = "0.0.0.0/0"
```

to 

```json
access_ip      = "<YOUR IP>/32"
```

## Create SSH Keypair

```sh
ssh-keygen -f <AS NAMED IN VARS.TF private_key_path> -q -N ""
```

Example:

```sh
ssh-keygen -f cnctraining-key-pair -q -N ""
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

If you want to sniff around on your newly created little instance connect to it via:

```sh
# web1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_web1)

# web2
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_web2)

# db1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_db1)
```

## Create Findings

In the next step we're preparing some findings for Sentry.

```sh
scripts/create-findings.sh
```

Feel free to have a look on the script above, but in theory it should prepare six findings.

## Detroy

```sh
# destroy
terraform destroy
```
