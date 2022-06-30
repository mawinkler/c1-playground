# Add-On: Container Security

- [Add-On: Container Security](#add-on-container-security)
  - [Deploy](#deploy)
  - [Access Container Security](#access-container-security)
  - [Access Smart Check](#access-smart-check)
  - [Use Scan-Image and Scan-Namespace](#use-scan-image-and-scan-namespace)
  - [Support for Staging-CloudOne](#support-for-staging-cloudone)

## Deploy

> ***Note:*** The script `deploy-container-security.sh` uses the Cloud One API Key, which is managed in Cloud One, not Workload Security anymore. If you're not using the new Cloud One API Key and are logging in to Cloud One with an Account Name, e-Mail and Password copy the legacy version of this script found in the `legacy`-directory over the `deploy-container-security.sh` script in the root directory.

To deploy Container Security run:

```sh
$ ./deploy-smartcheck.sh
$ ./deploy-container-security.sh
```

## Access Container Security

Head over to your Cloud One Account and select the Container Security tile.

The deployment script automatically creates a policy for your cluster if it doesn't exist already. Some controls in the deploy section are either set to log or block, the continuous section is set to log only.

## Access Smart Check

Follow the steps for your platform below. A file called `services` is either created or updated with the link and the credentials to connect to Smart Check.

***Linux***

Example:

`Smart check UI on: https://192.168.1.121:8443 w/ admin/trendmicro`

***MacOS***

Example:

`Smart check UI on: https://smartcheck:443 w/ admin/trendmicro`

***Cloud9***

If working on a Cloud9 environment you need to adapt the security group of the corresponding EC2 instance to enable access from your browwer. To share Smart Check over the internet, follow the steps below.

1. Query the public IP of your Cloud9 instance with

   ```sh
   $ curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

2. In the IDE for the environment, on the menu bar, choose your user icon, and then choose Manage EC2 Instance
3. Select the security group associated to the instance and select Edit inbound rules.
4. Add an inbound rule for the `proxy_listen_port` configured in you config.json (default: 8443) and choose Source Anywhere
5. Depending on the currently configured Network ACL you might need to add a rule to allow ingoing traffic on the same port. To do this go to the VPC within the Cloud9 instance is running and proceed to the associated Main network ACL.
6. Ensure that an inbound rule is set which allows traffic on the `proxy_listen_port`. If not, click on `Edit inbound rules` and add a rule with a low Rule number, Custom TCP, Port range 8443 (or your configured port), Source 0.0.0.0/0 and Allow.

You should now be able to connect to Smart Check on the public ip of your Cloud9 with your configured port.

</details>

## Use Scan-Image and Scan-Namespace

The two scripts `scan-image.sh` and `scan-namespace.sh` do what you would expect. Running

```sh
$ ./scan-image.sh nginx:latest
```

starts an asynchronous scan of the latest version of nginx. The scan will run on Smart Check, but you are immedeately back in the shell. To access the scan results either use the UI or API of Smart Check.

If you add the flag `-s` the scan will be synchronous, so you get the scan results directly in your shell.

```sh
$ ./scan-image.sh -s nginx:latest
```

```json
...
{ critical: 6,
  high: 39,
  medium: 40,
  low: 13,
  negligible: 2,
  unknown: 3 }
```

The script

```sh
$ ./scan-namespace.sh
```

scans all used images within the current namespace. Eventually do a `kubectl config set-context --current --namespace <NAMESPACE>` beforehand to select the namespace to be scanned.

## Support for Staging-CloudOne

The Container Security deployment script does now support the use of CloudOnes staging environment. To use this one instead the of the production one add your staging API key in the relevant section of the `config.json`.

Additionally, in the `deploy-container-security.sh`-script set

```sh
STAGING=true
```
