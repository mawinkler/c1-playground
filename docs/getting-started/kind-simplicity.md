# Getting Started w/ the built in Cluster

Choose the platform documentation

## Ubuntu

Follow this chapter if...

- you're using the Playground on a Ubuntu machine (not Cloud9) and
- are going to use the built in cluster

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

Finally, create your local cluster by choosing `Create Cluster...` --> `Local Cluster`.

## Cloud9

Follow this chapter if...

- you're using the Playground on a AWS Cloud9 environment and
- are going to use the built in cluster

Follow the steps below to create a Cloud9 suitable for the Playground.

- Point your browser to AWS
- Choose your default AWS region in the top right
- Go to the Cloud9 service
- Select `[Create Cloud9 environment]`
- Name it as you like
- Choose `[t3.xlarge]` for instance type and
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

If you run the above command on a newly created or rebooted Cloud9 instance and are receiving the following error, just wait a minute or two and rerun the curl command. The reason for this error is, that directly after starting the machine some update processes are running in the background causing the lock to the package manager process.

```sh
E: Could not get lock /var/lib/dpkg/lock-frontend - open (11: Resource temporarily unavailable)
E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), is another process using it?
```

Choose `Bootstrap`. You will be asked for your AWS credentials. They will never be stored on disk and get removed from memory after creating and assigning an instance role to the Cloud9 instance.

If you forgot to disable AWS managed temporary credentials you will asked to do it again.

After the bootstrapping has finished exit the menu and the terminal. Then create a new terminal.

To restart the menu execute

```sh
playground
```

from anywhere in your terminal.

Finally, create your local cluster by choosing `Create Cluster...` --> `Local Cluster`.
