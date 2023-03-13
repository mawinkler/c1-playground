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

Example:

```sh
ssh-keygen -f cnctraining-key-pair -q -N ""
```

## Terraform

Prepare your terraform environment by running

```sh
# init
terraform init
```

Now, you're ready to create your lab environment on AWS :-)

```sh
# plan
terraform plan -out terraform.out

# apply
terraform apply terraform.out
```

For the impatient, simply run

```sh
terraform apply
```

## Access the EC2 instance(s)

If you want to sniff around on your newly created little instance connect to it via:

```sh
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip)
```

## Trigger an initial Sentry Scan

Next, let's scan our instance for malware and integrity findings. It should show up on the Cloud One Central console after some minutes, but normally shouldn't have findings assigned (unless something went terribly wrong on the AWS side).

```sh
INSTANCE=$(terraform output -raw public_instance_id) sentry-trigger-ebs-scan 
```

The above script creates the necessary input for our sentry State Machine and starts its execution.

You can verify that it's running by checking on the AWS console `Step Functions --> State Machines --> ScannerStateMachine-<RANDOM>`.

## Create Findings

In the next step we're preparing some findings for Sentry.

```sh
scripts/create-findings.sh
```

Feel free to have a look on the script above, but in theory it should prepare six findings.

## Trigger a second Sentry Scan

Now, trigger a second scan and see what Sentry is able to detect.

```sh
INSTANCE=$(terraform output -raw public_instance_id) sentry-trigger-ebs-scan 
```

Check Cloud One console afterwards.

## Detroy

When you have finished this short lab run the following two commands to wipe your steps.

```sh
# delete snapshots
sentry-remove-snapshots

# destroy
terraform destroy
```
