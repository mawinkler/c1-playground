#!/bin/bash

# Prepare the following Deployment policy
#
# Kubectl Access
#   Log - attempts to execute in/attach to a container
#   Log - attempts to establish port-forward on a container
# Exceptions
#   Check - Allow images with paths that equal docker.io/mawinkler/ubuntu:latest
# Error Ruleset
#   Log - TM-00000010 - (T1543)Launch Package Management Process in Container

. $PGPATH/demos/third_party/demo-magic/demo-magic.sh

# demo-magic
TYPE_SPEED=50
PROMPT_TIMEOUT=3
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# Source helpers
. $PGPATH/playground-helpers.sh

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

