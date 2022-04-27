#!/bin/bash

. ./third_party/demo-magic/demo-magic.sh

# demo-magic
TYPE_SPEED=30
PROMPT_TIMEOUT=3
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# playground
# configure the directory of your playground clone here
PLAYGROUND_DIR="../"
# get registry parameters
REG_USERNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .username' ${PLAYGROUND_DIR}/config.json)"
REG_PASSWORD="$(jq -r '.services[] | select(.name=="playground-registry") | .password' ${PLAYGROUND_DIR}/config.json)"
REG_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' ${PLAYGROUND_DIR}/config.json)"
REG_NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' ${PLAYGROUND_DIR}/config.json)"
REG_HOST=$(kubectl --namespace ${REG_NAMESPACE} get svc ${REG_NAME} \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
REG_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' ${PLAYGROUND_DIR}/config.json)"

# script
clear
echo
echo "===== ENTER admin ====="
echo

NO_WAIT=true
p "${GREEN}# Our company decided to integrate the new Container Security solution from Trend Micro."
wait

p "${GREEN}# Luckily, there are some nice scripts we can use to set it up easily within our until now unsecured cluster."
wait

p "${GREEN}# So, let's deploy. We start with the image scanner."
wait

NO_WAIT=false
#pe
p "./deploy-smartcheck.sh"
/bin/bash -c "cd ${PLAYGROUND_DIR} && ./deploy-smartcheck.sh"
# cat logs/deploy-smartcheck.log
wait

NO_WAIT=true
p "${GREEN}# Next and final step we deploy the admission controller and the continuous compliance compotent."
wait

p "${GREEN}# An initial but already secure policy will be applied directly to our cluster."
wait

NO_WAIT=false
#pe
p "./deploy-container-security.sh"
/bin/bash -c "cd ${PLAYGROUND_DIR} && ./deploy-container-security.sh"
# cat logs/deploy-container-security.log
wait

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
p "${GREEN}# Bunk, I should have known that. My security officer did inform me about new security controls in place."
wait

p "${GREEN}# So let's scan the nginx, should be good, I guess."
wait

NO_WAIT=false
p "./scan-image.sh -s nginx:latest"
/bin/bash -c "cd ${PLAYGROUND_DIR} && ./scan-image.sh -s nginx:latest"
echo

NO_WAIT=true
p "${GREEN}# Hmm, vulnerabilities exceeded threshold. Let's try the deployment again..."
wait

NO_WAIT=false
pe "kubectl create deployment --image=nginx --namespace nginx nginx"
echo

NO_WAIT=true
p "${GREEN}# Uuups, still not working!"
wait

p "${GREEN}# Right... I scanned the image in the internal registry but tried to deploy from docker hub."
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
      - image: ${REG_HOST}:${REG_PORT}/nginx:latest
        name: nginx
        resources: {}
      imagePullSecrets:
      - name: regcred
status: {}
EOF

pe "cat nginx.yaml"
echo

NO_WAIT=true
p "${GREEN}# Now, create the image pull secrets and try to deploy nginx again."
wait

IMAGE_PULL_SECRETS="kubectl create secret docker-registry regcred --docker-server=${REG_HOST}:${REG_PORT} --docker-username=${REG_USERNAME} --docker-password=${REG_PASSWORD} --docker-email=info@mail.com --namespace nginx"

NO_WAIT=false
pe "${IMAGE_PULL_SECRETS}"
echo

pe "kubectl -n nginx apply -f nginx.yaml"
echo

NO_WAIT=true
p "${GREEN}# Stupid me, I should have known that. Scanning the nginx:latest image already told me that."
wait

p "${GREEN}# Let me ping the admin if he can set an exception for now."
wait

clear
NO_WAIT=true
echo
echo "===== ENTER admin ====="
echo
p "${GREEN}# Soooo, my favourite developer asked me to set an exception for his nginx which he needs to test."
wait

p "${GREEN}# I'll do this for now, since he promised to fix the image shortly."
wait

NO_WAIT=false
pe "kubectl label ns nginx ignoreAdmissionControl=true --overwrite"
echo

pe "kubectl get ns --show-labels nginx"
wait

clear
NO_WAIT=true
echo
echo "===== ENTER developer ====="
echo
pe "kubectl -n nginx apply -f nginx.yaml"
echo

kubectl delete namespace nginx > /dev/null 2>&1
