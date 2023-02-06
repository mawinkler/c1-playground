# Usage

> ***Note:*** Docker hub credentials are required

Adapt the DOCKER_USERNAME in the script `publish.sh` if needed. Then run

```sh
./publish.sh
```

Run demo with

```sh
export DOCKER_USERNAME=<YOUR DOCKER USERNAME>

kubectl run -it --image=docker.io/${DOCKER_USERNAME}/ubuntu:latest debug --restart=Never --rm -- /bin/bash -c /root/demo/demo-c1cs-rt.sh
```
