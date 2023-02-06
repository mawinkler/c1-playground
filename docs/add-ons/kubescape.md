# Add-On: Kubescape

## Install the Kubescape CLI

```sh
curl -s https://raw.githubusercontent.com/armosec/kubescape/master/install.sh | /bin/bash
```

## Run a full Scan

```sh
export ARMO_ACCOUNT=XXX
kubescape scan framework nsa,mitre,armobest \
  --submit --enable-host-scan --format-version v2 --verbose \
  --exclude-namespaces=kube-system --fail-threshold 0 \
  --account ${ARMO_ACCOUNT} --submit
```
