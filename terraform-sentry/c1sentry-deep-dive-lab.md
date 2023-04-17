# Play with the Playground (on Cloud9)

- [Play with the Playground (on Cloud9)](#play-with-the-playground-on-cloud9)
  - [Prepare for the Lab](#prepare-for-the-lab)
  - [Optional: Adapt `vars.tf`](#optional-adapt-varstf)
  - [Create SSH Keypair](#create-ssh-keypair)
  - [Create Environment with Terraform](#create-environment-with-terraform)
  - [Play with an EC2 Instance](#play-with-an-ec2-instance)
    - [Access the EC2 Instance(s)](#access-the-ec2-instances)
    - [Trigger an initial Sentry Scan](#trigger-an-initial-sentry-scan)
    - [Create Findings](#create-findings)
    - [Trigger a second Sentry Scan](#trigger-a-second-sentry-scan)
  - [Other Tools for Sentry provided by the Playground](#other-tools-for-sentry-provided-by-the-playground)
  - [Tear Down](#tear-down)

## Prepare for the Lab

Follow the steps below to create a Cloud9 suitable for the Playground.

- Point your browser to AWS
- Choose your default AWS region in the top right
- Go to the Cloud9 service
- Select `[Create Cloud9 environment]`
- Name it as you like
- Choose `[t3.medium]` for instance type and
- `Ubuntu 18.04 LTS` as the platform
- For the rest take all default values and click `[Create environment]`

Update IAM Settings for the Workspace

- Click the gear icon (in top right corner), or click to open a new tab and choose `[Open Preferences]`
- Select AWS SETTINGS
- Turn OFF `[AWS managed temporary credentials]`
- Close the Preferences tab

Now, run the Playground

```sh
curl -fsSL https://raw.githubusercontent.com/mawinkler/c1-playground/master/bin/playground | bash && exit
```

If you run the above command on a newly created or rebooted Cloud9 instance and are receiving the following error, just wait a minute or two and rerun the curl command. The reason for this error is, that directly after starting the machine some update processes are running in the background causing the lock to the package manager process.

```sh
E: Could not get lock /var/lib/dpkg/lock-frontend - open (11: Resource temporarily unavailable)
E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), is another process using it?
```

Choose `Bootstrap`. You will be asked for your AWS credentials. They will never be stored on disk and get removed from memory after creating and assigning an instance role to the Cloud9 instance.

If you forgot to disable AWS managed temporary credentials you will asked to do it again.

The bootstrapping process will exit your current terminal or shell after it has done it's work. Depending on your environment just create a new terminal session and continue.

Change in the terraform subdirectory of the Playground:

```sh
cd $PGPATH/terraform
```

## Optional: Adapt `vars.tf`

The `vars.tf`-file contains some definitions like the AWS region and availability zone to use. Adapt it to your needs as required.

If you are working on a shared AWS environment you likely want to change `PRIVATE_KEY_PATH` and `PUBLIC_KEY_PATH` to make it unique in your environment.

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
```

## Create SSH Keypair

```sh
ssh-keygen -f <AS NAMED IN vars.tf PRIVATE_KEY_PATH> -q -N ""
```

Example:

```sh
ssh-keygen -f cnctraining-key-pair -q -N ""
```

## Create Environment with Terraform

Prepare your terraform environment by running

```sh
# init
terraform init
```

```sh
Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v4.59.0...
- Installed hashicorp/aws v4.59.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Now, you're ready to create your lab environment on AWS :-)

```sh
# plan
terraform plan -out terraform.out
```

The command above will create a long output explaining what terraform will to for you when you apply the plan.

```sh
# apply
terraform apply terraform.out
```

For the impatient, simply run

```sh
terraform apply
```

## Play with an EC2 Instance

### Access the EC2 Instance(s)

If you want to sniff around on your newly created little instance connect to it via:

```sh
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no \
  ubuntu@$(terraform output -raw public_instance_ip)
```

### Trigger an initial Sentry Scan

Next, let's scan our instance for malware and integrity findings. It should show up on the Cloud One Central console after some minutes, but normally shouldn't have findings assigned (unless something went terribly wrong on the AWS side).

```sh
INSTANCE=$(terraform output -raw public_instance_id) sentry-trigger-ebs-scan
```

The above script creates the necessary input for our sentry State Machine and starts its execution.

You can verify that it's running by checking on the AWS console `Step Functions --> State Machines --> ScannerStateMachine-<RANDOM>`. Wait for the state machine to finish and the EC2 instance is listed on Cloud One Central. Their shoudn't be any findings, yet.

### Create Findings

In the next step we're preparing some findings for Sentry.

```sh
scripts/create-findings.sh
```

Feel free to have a look on the script above, but in theory it should prepare two malware and six integrity findings.

### Trigger a second Sentry Scan

Now, trigger a second scan and see what Sentry is able to detect.

```sh
INSTANCE=$(terraform output -raw public_instance_id) sentry-trigger-ebs-scan 
```

Check Cloud One Central console afterwards. It might take some minutes for findings to show up in Sentry.

## Other Tools for Sentry provided by the Playground

They might come in handy if you continue playing with Sentry. The documentation for all these tools is located here: [Playground Pages](https://mawinkler.github.io/playground-pages/play/tools/)

## Tear Down

When you have finished this short lab run the following two commands to wipe your steps.

```sh
# delete snapshots
sentry-remove-snapshots

# destroy
terraform destroy
```

**Lab done**

Thank you,  
*Markus*
