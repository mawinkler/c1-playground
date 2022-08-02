# Getting Started with managed Clusters

- [Getting Started with managed Clusters](#getting-started-with-managed-clusters)
  - [Choose the platform documentation](#choose-the-platform-documentation)
    - [Ubuntu or MacOS](#ubuntu-or-macos)
    - [Cloud9](#cloud9)

## Choose the platform documentation

- [Ubuntu or MacOS](#ubuntu-or-macos)
- [Cloud9](#cloud9)

### Ubuntu or MacOS

Follow this chapter if...

- you're using the Playground on a Ubuntu machine and
- are going to use either EKS, AKS or GKE

> The only preparation needed is to have an authenticated CLI for the chosen cloud provider.

### Cloud9

Follow this chapter if...

- you're using the Playground on a AWS Cloud9 environment and
- are going to use EKS as the cluster

> Follow the steps below to create a Cloud9 suitable for the Playground with EKS
>
> - Point your browser to AWS
> - Choose your default AWS region in the top right
> - Go to the Cloud9 service
> - Select `[Create Cloud9 environment]`
> - Name it as you like
> - Choose `[t3.medium]` for instance type and
> - `Ubuntu 18.04 LTS` as the platform
> - For the rest take all default values and click `[Create environment]`
>
> Install the version 2.6.1 of the AWS CLI v2
>
> ```sh
> curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.6.1.zip" \
>   -o "awscliv2.zip"
> unzip /tmp/awscliv2.zip -d /tmp
> sudo /tmp/aws/install
> ```
>
> Update IAM Settings for the Workspace
>
> - Click the gear icon (in top right corner), or click to open a new tab and choose `[Open Preferences]`
> - Select AWS SETTINGS
> - Turn off `[AWS managed temporary credentials]`
> - Close the Preferences tab
>
> To create an IAM role which we want to attach to our Cloud9 instance, we need temporarily ***administrative privileges*** in our current shell. To get these, we need to configure our `aws` cli with our AWS credentials and the current region. Directly after assigning the created role to the instance, we're removing the credentials from the environment, of course.
>
> ```sh
> aws configure
> ```
>
> In this example I'm using `eu-central-1`. Change it to your current AWS region.
>
> ```sh
> AWS Access Key ID [None]: <KEY>
> AWS Secret Access Key [None]: <SECRET>
> Default region name [None]: eu-central-1
> Default output format [None]: json
> ```
>
> Now, run the following script, which creates and assigns the required instance role to your Cloud9 instance.
>
> ```sh
> REPO=https://raw.githubusercontent.com/mawinkler/c1-playground/master
> sudo apt install -y jq && \
>   curl -L ${REPO}/tools/cloud9-instance-role.sh | bash
> ```
>
> Use the GetCallerIdentity CLI command to validate that the Cloud9 IDE is using the correct IAM role.
>
> ```sh
> aws sts get-caller-identity --query Arn | \
>   grep ekscluster-admin -q && \
>   echo "IAM role valid" || echo "IAM role NOT valid"
> ```
>
> Finally, resize the virtual disk of your Cloud9 by running
>
> ```sh
> curl -L ${REPO}/tools/cloud9-resize.sh | bash
> ```
