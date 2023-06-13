# Demo Scripts

> ***TODO:*** Migrate to ASaaS

The Playground supports automated scripts to demonstrate functionalities of deployments. Currently, there are two scripts available showing some capabilities of Cloud One Container Security.

To run them, ensure to have an EKS cluster up and running and have Smart Check and Container Security deployed.

After configuring the policy and rule set as shown below, you can run the demos with

```sh
# Deployment Control Demo
./demos/demo-c1cs-dc.sh

# Runtime Security Demo
./demos/demo-c1cs-rt.sh
```

## Deployment Control Demo

> ***Storyline:*** A developer wants to try out a new `nginx` image but fails since the image has critical vulnerabilities, he tries to deploy from docker hub etc. Lastly he tries to attach to the pod, which is prevented by Container Security.

To prepare for the demo verify that the cluster policy is set as shown below:

- Pod properties
  - uncheck - containers that run as root
  - Block - containers that run in the host network namespace
  - Block - containers that run in the host IPC namespace
  - Block - containers that run in the host PID namespace
- Container properties
  - Block - containers that are permitted to run as root
  - Block - privileged containers
  - Block - containers with privilege escalation rights
  - Block - containers that can write to the root filesystem
- Image properties
  - Block - images from registries with names that DO NOT EQUAL REGISTRY:PORT
  - uncheck - images with names that
  - Log - images with tags that EQUAL latest
  - uncheck - images with image paths that
- Scan Results
  - Block - images that are not scanned
  - Block - images with malware
  - Log - images with content findings whose severity is CRITICAL OR HIGHER
  - Log - images with checklists whose severity is CRITICAL OR HIGHER
  - Log - images with vulnerabilities whose severity is CRITICAL OR HIGHER
  - Block - images with vulnerabilities whose CVSS attack vector is NETWORK and whose severity is HIGH OR HIGHER
  - Block - images with vulnerabilities whose CVSS attack complexity is LOW and whose severity is HIGH OR HIGHER
  - Block - images with vulnerabilities whose CVSS availability impact is HIGH and whose severity is HIGH OR HIGHER
  - Log - images with a negative PCI-DSS checklist result with severity CRITICAL OR HIGHER
- Kubectl Access
  - Block - attempts to execute in/attach to a container
  - Log - attempts to establish port-forward on a container

Most of it should already configured by the `deploy-container-security.sh` script.

Run the demo being in the playground directory with

```sh
./demos/demo-c1cs-dc.sh
```

## Runtime Security Demo

> ***Storyline:*** A kubernetes admin newbie executes some information gathering about the kubernetes cluster from within a running pod. Finally, he gets kicked by Container Security because of the `kubectl` usage.

To successfully run the runtime demo you need adjust the aboves policy slightly.

Change:

- Kubectl Access
  - Log - attempts to execute in/attach to a container

- Exceptions
  - Allow images with paths that equal `docker.io/mawinkler/ubuntu:latest`

Additionally, set the runtime rule `(T1543)Launch Package Management Process in Container` to ***Log***. Normally you'll find that rule in the `*_error` ruleset.

Run the demo being in the playground directory with

```sh
./demos/demo-c1cs-rt.sh
```

The demo starts locally on your system, but creates a pod in the `default` namespace of your cluster using a slightly pimped ubuntu image which is pulled from my docker hub account. The main demo runs within that pod on the cluster, not on your local machine.

The Dockerfile for this image is in `./demos/pod/Dockerfile` for you to verify, but you do not need to build it yourself.
