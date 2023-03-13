# Create a simple AWS Sentry Playground

## Prepare

Ensure the latest AWS CLI via the Playground menu `Tools --> CLIs --> AWS`

Change in the terraform subdirectory

```sh
cd $PGPATH/terraform
```

## Optional: Adapt `vars.tf`

The `vars.tf`-file contains some definitions like the AWS region and availability zone to use. Adapt it to your needs as required.

If you are working on a shared environment you likely want to change `PRIVATE_KEY_PATH` and `PUBLIC_KEY_PATH` to make it unique in your environment.

```json
variable "AWS_REGION" {
  default = "eu-central-1"
}

variable "AWS_AZ" {
  default = "eu-central-1a"
}

variable "PRIVATE_KEY_PATH" {
  default = "cnctraining-key-pair"
}

variable "PUBLIC_KEY_PATH" {
  default = "cnctraining-key-pair.pub"
}

variable "EC2_USER" {
  default = "ubuntu"
}
````

## Create SSH Keypair

```sh
ssh-keygen -f <AS NAMED IN VARS.TF PRIVATE_KEY_PATH> -q -N ""
```

## Terraform

```sh
# plan
terraform plan -out terraform.out

# apply
terraform apply terraform.out
```

## Access the EC2 instance(s)

If you want to sniff around on your newly created little instance connect to it via:

```sh
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip)
```

## Trigger an initial Sentry Scan

```sh
INSTANCE=$(terraform output -raw public_instance_id) sentry-trigger-ebs-scan 
```

## Create Findings

```sh
scripts/create-findings.sh
```

## Trigger a second Sentry Scan

```sh
INSTANCE=$(terraform output -raw public_instance_id) sentry-trigger-ebs-scan 
```

Check Cloud One console afterwards.

## Detroy

```sh
# delete snapshots
sentry-remove-snapshots

# destroy
terraform destroy
```
