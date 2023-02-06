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

. $PGPATH/demos/third_party/demo-magic/demo-magic.sh

# demo-magic
TYPE_SPEED=50
PROMPT_TIMEOUT=3
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# Source helpers
. $PGPATH/bin/playground-helpers.sh

# get registry parameters
get_registry_credentials

# script
clear
NO_WAIT=true
echo
echo "===== ENTER developer ====="
echo
p "${GREEN}# So, let's try out the latest nginx image for this new project."
wait

p "${GREEN}# First, I need to create the namepace and then I'm going to deploy the nginx."
wait

NO_WAIT=false
pe "kubectl create namespace nginx"
echo

pe "kubectl create deployment --image=nginx --namespace nginx nginx"
echo

NO_WAIT=true
p "${GREEN}# Bunk, I should have known that. My security officer did inform me about new security controls in place which enforce"
p "${GREEN}# various controls to our clusters."
wait

p "${GREEN}# Let me check his mail again..."
wait

p "mail"
cat $PGPATH/demos/logs/mail.txt
wait
wait
wait

p "${GREEN}# So let's pull the image and push it to our private registry."
p "${GREEN}# Then I'm going to issue an image scan on the nginx which should be good, I guess."
wait

p "${GREEN}# As being told, I should not use latest so I go for the version 1.21.6."
wait

NO_WAIT=false
pe "$PGPATH/scan-image.sh -s nginx:1.21.6"
# wait
# cat $PGPATH/demos/logs/scan.json | jq .
# /bin/bash -c "$PGPATH/scan-image.sh -s nginx:1.21.6"
echo

NO_WAIT=true
p "${GREEN}# Hmm, the scanner did find some vulnerabilities in the image."
p "${GREEN}# Let's try the deployment again..."
wait

NO_WAIT=false
pe "kubectl create deployment --image=nginx --namespace nginx nginx"
echo

NO_WAIT=true
p "${GREEN}# Uuups, still not working! It's telling me (amongst others), that the image is still unscanned."
wait

p "${GREEN}# Right... I scanned the image in the internal registry but tried to deploy from docker hub."
wait

p "${GREEN}# Additionally, I need to patch the deployment to satisfy the required security context as shown, of course."
wait

p "${GREEN}# Let's do it correctly."
wait

NO_WAIT=false
cat <<EOF >nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: nginx
  name: nginx
  namespace: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - image: ${REGISTRY}/nginx:1.21.6
        name: nginx
        resources: {}
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          runAsNonRoot: false
      imagePullSecrets:
      - name: regcred
status: {}
EOF

pe "cat nginx.yaml"
echo

NO_WAIT=true
p "${GREEN}# Now, create the image pull secrets and try to deploy nginx again."
wait

IMAGE_PULL_SECRETS="kubectl create secret docker-registry regcred \\
  --docker-server=${REGISTRY} \\
  --docker-username=${REGISTRY_USERNAME} \\
  --docker-password=**************** \\
  --docker-email=dev@corp.com \\
  --namespace nginx"

NO_WAIT=false
p "${IMAGE_PULL_SECRETS}"
kubectl create secret docker-registry regcred \
  --docker-server=${REGISTRY} \
  --docker-username=${REGISTRY_USERNAME} \
  --docker-password=${REGISTRY_PASSWORD} \
  --docker-email=dev@corp.com \
  --namespace nginx
echo

pe "kubectl -n nginx apply -f nginx.yaml"
echo

NO_WAIT=true
p "${GREEN}# Stupid me, I should have known that. Scanning the nginx image already told me that."
wait

p "${GREEN}# Additionally, I need to modify the Dockerfile to run nginx without root."
wait

p "${GREEN}# Nginx needs read and write access to /var/run/nginx.pid and /var/cache/nginx."
wait

p "${GREEN}# Lastly, it can't listen on ports 80 and 443."
wait

p "${GREEN}# I keep that for later, though."
wait

p "${GREEN}# Let me ping the admin if he can set an exception for now."
wait
wait
wait
wait

clear
NO_WAIT=true
echo
echo "===== ENTER admin ====="
echo
p "${GREEN}# Soooo, my favourite developer asked me to set an exception for his nginx which he needs to test."
wait

p "${GREEN}# I'll do this for now, since he promised to fix the image shortly."

# here, I'm faking an exception made within the policy
kubectl label ns nginx ignoreAdmissionControl=true --overwrite > /dev/null 2>&1

wait
wait

clear
NO_WAIT=true
echo
echo "===== ENTER developer ====="
echo
pe "kubectl -n nginx apply -f nginx.yaml"
echo

p "${GREEN}# Let's check"
wait

pe "kubectl get pods -n nginx"
wait

# we enable admission control again
kubectl label ns nginx ignoreAdmissionControl- > /dev/null 2>&1

p "${GREEN}# Nice! I got my nginx :-), but need to resolve the vulnerabilities and security context issues found within shortly."
wait

p "${GREEN}# Let's have a closer look"
wait

pe "kubectl -n nginx exec -it $(kubectl -n nginx get pods -o=jsonpath='{.items[0].metadata.name}') -- /bin/sh"
echo

p "${GREEN}# :-("
p "${GREEN}# Allowing to attach to a running pod can be dangerous. Need to rethink my debugging procedures."
wait

kubectl delete namespace nginx > /dev/null 2>&1
