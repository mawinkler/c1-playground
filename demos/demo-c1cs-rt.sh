#!/bin/bash

# Prepare the following Deployment policy
#
# Pod properties
#   uncheck - containers that run as root
#   Block - containers that run in the host network namespace
#   Block - containers that run in the host IPC namespace
#   Block - containers that run in the host PID namespace
# Container properties
#   Block - containers that are permitted to run as root
#   Block - privileged containers
#   Block - containers with privilege escalation rights
#   Block - containers that can write to the root filesystem
# Image properties
#   Block - images from registries with names that DO NOT EQUAL REGISTRY:PORT
#   uncheck - images with names that
#   Log - images with tags that EQUAL latest
#   uncheck - images with image paths that
# Scan Results
#   Block - images that are not scanned
#   Block - images with malware
#   Log - images with content findings whose severity is CRITICAL OR HIGHER
#   Log - images with checklists whose severity is CRITICAL OR HIGHER
#   Log - images with vulnerabilities whose severity is CRITICAL OR HIGHER
#   Block - images with vulnerabilities whose CVSS attack vector is NETWORK and whose severity is HIGH OR HIGHER
#   Block - images with vulnerabilities whose CVSS attack complexity is LOW and whose severity is HIGH OR HIGHER
#   Block - images with vulnerabilities whose CVSS availability impact is HIGH and whose severity is HIGH OR HIGHER
#   Log - images with a negative PCI-DSS checklist result with severity CRITICAL OR HIGHER
# Kubectl Access
#   Block - attempts to execute in/attach to a container
#   Log - attempts to establish port-forward on a container

. ./demos/third_party/demo-magic/demo-magic.sh

# demo-magic
TYPE_SPEED=50
PROMPT_TIMEOUT=3
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# Source helpers
. ./playground-helpers.sh

# get registry parameters
get_registry_credentials

# script
clear
NO_WAIT=true
echo
echo "===== ENTER red ====="
echo
p "${GREEN}# Running the following command should give me a shell within a container running on the cluster:"
wait

p "kubectl run -it --image=docker.io/ubuntu:latest debug --restart=Never --rm -- /bin/bash"
kubectl run -it --image=docker.io/mawinkler/ubuntu:latest debug --restart=Never --rm -- /bin/bash -c /root/demo/demo-c1cs-rt.sh

p "${GREEN}# Crabbeldicrap, I got killed :-("
wait

# kubectl run shell --restart=Never -it --image=docker.io/mawinkler/demo-magic:latest \
#     --rm --attach \
#     --overrides \
#     '
#     {
#         "spec":{
#         "hostPID": true,
#         "containers":[{
#             "name":"kod",
#             "image": "docker.io/mawinkler/demo-magic:latest",
#             "imagePullPolicy": "Always",
#             "stdin": true,
#             "tty": true,
#             "command":["/bin/bash"],
#             "nodeSelector":{
#             "dedicated":"master"
#             },
#             "securityContext":{
#             "privileged":true
#             }
#         }]
#         }
#     }
#     '

# kubectl run shell --restart=Never -it --image=docker.io/mawinkler/demo-magic:latest \
#     --rm --attach \
#     --overrides \
#     '
#     {
#         "spec":{
#         "hostPID": true,
#         "containers":[{
#             "name":"kod",
#             "image": "docker.io/mawinkler/demo-magic:latest",
#             "imagePullPolicy": "Always",
#             "stdin": true,
#             "tty": true,
#             "command":["/bin/bash", "-c", "/root/demo/demo-c1cs-rt.sh"],
#             "nodeSelector":{
#             "dedicated":"master"
#             },
#             "securityContext":{
#             "privileged":true
#             }
#         }]
#         }
#     }
#     '
# kubectl run -it --image=docker.io/mawinkler/demo-magic:latest --restart=Never --rm demo -- /bin/bash -c '/root/demo/demo-c1cs-rt.sh'
echo

