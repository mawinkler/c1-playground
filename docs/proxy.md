# Using a Proxy with Container Security

- [Using a Proxy with Container Security](#using-a-proxy-with-container-security)
  - [Overrides](#overrides)
  - [Kind](#kind)

## Overrides

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

## Kind

Set the following environment variables before creating the cluster

```sh
# export HTTP_PROXY=172.17.0.1:3128
# export HTTPS_PROXY=172.17.0.1:3128
# export NO_PROXY=localhost,127.0.0.1
```
