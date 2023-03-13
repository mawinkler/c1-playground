# Add-On: Container Security

## Deploy

> ***Note:*** The script `deploy-container-security.sh` uses the Cloud One API Key, which is managed in Cloud One, not Workload Security anymore. If you're not using the new Cloud One API Key and are logging in to Cloud One with an Account Name, e-Mail and Password copy the legacy version of this script found in the `legacy`-directory over the `deploy-container-security.sh` script in the root directory.

To deploy Container Security run:

```sh
deploy-container-security.sh
deploy-smartcheck.sh
```

## Access Container Security

Head over to your Cloud One Account and select the Container Security tile.

The deployment script automatically creates a policy for your cluster if it doesn't exist already. Some controls in the deploy section are either set to log or block, the continuous section is set to log only.

## Access Smart Check

Follow the steps for your platform below. A file called `services` is either created or updated with the link and the credentials to connect to Smart Check.

***Linux***

Example:

`Smart check UI on: https://192.168.1.121:8443 w/ admin/trendmicro`

***Cloud9***

If working on a Cloud9 environment you need to adapt the security group of the corresponding EC2 instance to enable access from your browwer. To share Smart Check over the internet, follow the steps below.

1. Query the public IP of your Cloud9 instance with

   ```sh
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

2. In the IDE for the environment, on the menu bar, choose your user icon, and then choose Manage EC2 Instance
3. Select the security group associated to the instance and select Edit inbound rules.
4. Add an inbound rule for the `proxy_listen_port` configured in you config.yaml (default: 8443) and choose Source Anywhere
5. Depending on the currently configured Network ACL you might need to add a rule to allow ingoing traffic on the same port. To do this go to the VPC within the Cloud9 instance is running and proceed to the associated Main network ACL.
6. Ensure that an inbound rule is set which allows traffic on the `proxy_listen_port`. If not, click on `Edit inbound rules` and add a rule with a low Rule number, Custom TCP, Port range 8443 (or your configured port), Source 0.0.0.0/0 and Allow.

You should now be able to connect to Smart Check on the public ip of your Cloud9 with your configured port.

</details>

## Using a Proxy with Kind and Container Security

### Overrides

Add the following section to your overrides of Container Security:

Assumes, that the IP of the docker bridge is 172.17.0.1 if using kind. Otherwise simply put the IP/hostname of the proxy instead.

```yaml
proxy:
  httpProxy: 172.17.0.1:8081
  httpsProxy: 172.17.0.1:8081
  noProxy:
  - localhost
  - 127.0.0.1
  - .cluster.local
```

### Kind

Set the following environment variables before creating the cluster

```sh
export HTTP_PROXY=172.17.0.1:3128
export HTTPS_PROXY=172.17.0.1:3128
export NO_PROXY=localhost,127.0.0.1
```

## Automatically create Runtime Security Findings

Run

```sh
kubectl apply -f $PGPATH/demos/dockerfiles/atomic-red/AtomicRedDocker-FullFalco.yaml
```
