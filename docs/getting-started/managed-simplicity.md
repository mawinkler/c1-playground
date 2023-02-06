# Getting Started w/ managed Clusters

Choose the platform documentation

## Ubuntu

Follow this chapter if...

- you're using the Playground on a Ubuntu machine and
- are going to use either EKS, AKS or GKE

Test if `sudo` requires a password by running `sudo ls /etc`. If you don't get a password prompt you're fine, otherwise run.

```sh
sudo visudo -f /etc/sudoers.d/custom-users
```

Add the following line:

```sh
<YOUR USER NAME> ALL=(ALL) NOPASSWD:ALL 
```

Now, run the Playground

```sh
curl -fsSL https://raw.githubusercontent.com/mawinkler/c1-playground/master/bin/playground | bash
```

Choose Bootstrap.

After the bootstrapping has finished exit the menu and the terminal. Then create a new terminal.

To restart the menu execute

```sh
playground
```

from anywhere in your terminal.

Now, choose the option `Install/Update CLI...` --> `AWS`.

Finally, create your EKS cluster by choosing `Create Cluster...` --> `Elastic Kubernetes Cluster`.

> ***Note:*** If you want to use AKS or GKE install the CLIs, authenticate to your cloud account on the terminal and choose the corresponding cluster type.

## Cloud9

Follow this chapter if...

- you're using the Playground on a AWS Cloud9 environment and
- are going to use EKS as the cluster

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
curl -fsSL https://raw.githubusercontent.com/mawinkler/c1-playground/master/bin/playground | bash
```

Choose `Bootstrap`. You will be asked for your AWS credentials. They will never be stored on disk and get removed from memory after creating and assigning an instance role to the Cloud9 instance.

If you forgot to disable AWS managed temporary credentials you will asked to do it again.

After the bootstrapping has finished exit the menu and the terminal. Then create a new terminal.

To restart the menu execute

```sh
playground
```

from anywhere in your terminal.

Now, choose the option `Install/Update CLI...` --> `AWS`.

Finally, create your EKS cluster by choosing `Create Cluster...` --> `Elastic Kubernetes Cluster`.

> ***Note:*** If you want to use AKS or GKE install the CLIs, authenticate to your cloud account on the terminal and choose the corresponding cluster type.
