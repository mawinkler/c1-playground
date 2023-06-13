# Add-On: Container Security

## Deploy

To deploy Container Security go to `Services --> Deploy` and choose Container Security.

## Access Container Security

Head over to your Cloud One Account and select the Container Security tile.

The deployment script automatically creates a policy for your cluster if it doesn't exist already. Some controls in the deploy section are either set to log or block, the continuous section is set to log only.

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

## Automatically create Runtime Security and Sentry Findings 

To get as much events as possible for runtime detection either uncheck or log only the following parameters in your deployment policy:

- Kubectl access
  - attempts to execute in/attach to a container
  - attempts to establish port-forward on a container

Ensure that an exception exists with

Allow images with paths that equal `mawinkler/atomic_red_docker:latest`.

Now, run

```sh
kubectl apply -f $PGPATH/demos/dockerfiles/atomic-red/AtomicRedDocker-FullFalco.yaml
```

Soon, you should find quite a lot of events logged for runtime security. Additionally, if Sentry scans your cluster it should detect multiple malwares as well :-).
