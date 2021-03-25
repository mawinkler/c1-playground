# Lab Guide

- [Lab Guide](#lab-guide)
  - [Prepare the Training Server](#prepare-the-training-server)
  - [Configure](#configure)
  - [Start Linux](#start-linux)
  - [Lab 1 - Registry Pull and Push](#lab-1---registry-pull-and-push)
  - [Lab 2 - Create a Deployment on Kubernetes](#lab-2---create-a-deployment-on-kubernetes)
  - [Lab 3 - Container Security #1](#lab-3---container-security-1)
  - [Lab 4 - Container Security #2](#lab-4---container-security-2)
  - [Lab 5 - Container Security #3](#lab-5---container-security-3)
  - [Tear Down](#tear-down)

## Prepare the Training Server

This quick lab guide is based on the training server, but you should be able to use any Linux with a bash (at least in theory). Please ensure, that your server has at least 2 CPUs and >= 8 GB memory.

Two variants for the preparation.

<details>
<summary>Using a fresh training machine w/o microk8s</summary>

First, ensure to have docker installed with `docker ps`. If that fails install Docker with

```sh
curl -fsSL get.docker.com -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker trendmicro && sudo service docker start
```

Then, logout of the shell an reconnect to the machine. Then proceed with the installation of `kind`.
</details>

<details>
<summary>Reusing the training machine w/ microk8s</summary>

First, we need to clean up a little

```sh
microk8s.stop
sudo snap remove jq microk8s helm kubectl
```

Now, please logout from your ssh or console session before proceeding and relogin again. This will clean up your environment.

</details>

Next, please install `kind`.

```sh
# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.9.0/kind-linux-amd64
chmod +x ./kind
sudo mv kind /usr/local/bin/
```

Following this, we install the full verions of `helm`, `kubectl`, `nginx` and `jq`

```sh
# kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# nginx
sudo apt install -y nginx

# jq
sudo add-apt-repository universe
sudo apt update
sudo apt install -y jq

# there you go :)
```

## Configure

After cloning the repo to your machine create your personal configuration file.

```sh
git clone https://github.com/mawinkler/c1-playground.git
cd c1-playground
cp config.json.sample config.json
```

Typically you don't need to change anything here besides setting your api key for C1 and an activation key for smart check.

```json
{
    ...
    "api_key": "YOUR KEY HERE",
    "activation_key": "YOUR KEY HERE"
}
```

Now, let's start the cluster

```sh
# Create the cluster with registries, load balancer and ingress controller
./up.sh
```

At this point we need to determine the network that is being used for the node ip pool. For that, we need to run `up.sh` and then query the nodes.

```sh
kubectl get nodes -o json | jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address'
```

```sh
172.18.0.2
```

The `up.sh` script will deploy a load balancer amongst others. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `X.X.255.1-X.X.255.250`. If the registry is deployed it will very likely be the second service requesting a load balancer IP, so typically it will get the `172.18.255.2` assignend which we define as an insecure registry for our local docker daemon.

To do this, create or modify `/etc/docker/daemon.json` to include a small subset probable ips for the registry.

```sh
sudo vi /etc/docker/daemon.json
```

```json
{"insecure-registries": ["172.18.255.1:5000","172.18.255.2:5000","172.18.255.3:5000"]}
```

Finally restart the docker daemon.

```sh
./down.sh
sudo systemctl restart docker
```

## Start Linux

```sh
# Create the cluster with registries, load balancer and ingress controller
./up.sh

# Deploy Smart Check
./deploy-smartcheck.sh

# Deploy the reverse upstream proxy
./deploy-proxy.sh
```

## Lab 1 - Registry Pull and Push

```sh
# Pull hello-app:1.0 from Google and push it to the cluster registry
# Verify w/ curl if the image is in the registry
REGISTRY_NAME="$(jq -r '.registry_name' config.json)"
REGISTRY_NAMESPACE="$(jq -r '.registry_namespace' config.json)"
REGISTRY_USERNAME="$(jq -r '.registry_username' config.json)"
REGISTRY_PASSWORD="$(jq -r '.registry_password' config.json)"
REGISTRY_PORT="$(jq -r '.registry_port' config.json)"
REGISTRY_IP=$(kubectl get svc -n ${REGISTRY_NAMESPACE} ${REGISTRY_NAME} \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ${REGISTRY_PASSWORD} | docker login https://${REGISTRY_IP}:${REGISTRY_PORT} --username ${REGISTRY_USERNAME} --password-stdin

docker pull gcr.io/google-samples/hello-app:1.0
docker tag gcr.io/google-samples/hello-app:1.0 ${REGISTRY_IP}:${REGISTRY_PORT}/hello-app:1.0
docker push ${REGISTRY_IP}:${REGISTRY_PORT}/hello-app:1.0
curl -k https://${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}@${REGISTRY_IP}:${REGISTRY_PORT}/v2/_catalog
```

You should get

```sh
{"repositories":["hello-app"]}
```

## Lab 2 - Create a Deployment on Kubernetes

```sh
# create a pull secret and deployment
kubectl create secret docker-registry regcred --docker-server=${REGISTRY_IP}:${REGISTRY_PORT} --docker-username=${REGISTRY_USERNAME} --docker-password=${REGISTRY_PASSWORD} --docker-email=info@mail.com

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
  name: hello-server
  labels:
    app: hello-server
spec:
  type: LoadBalancer
  ports:
  - port: 8080
    name: hello-server
    targetPort: 8080
  selector:
    app: hello-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: hello-server
  name: hello-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-server
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: hello-server
    spec:
      containers:
      - image: ${REGISTRY_IP}:${REGISTRY_PORT}/hello-app:1.0
        name: hello-app
        ports:
        - containerPort: 8080
      imagePullSecrets:
      - name: regcred
EOF

echo Try: curl $(kubectl --namespace default get svc hello-server \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080
```

You should get

```sh
Hello, world!
Version: 1.0.0
Hostname: hello-server-6488746978-vvtdx
```

Now, we scale the echo-server deployment to three instances with

```sh
kubectl scale deployment hello-server --replicas=3
```

If you now do the previous curl a couple of times, you should should see that different pods are accessed.

## Lab 3 - Container Security #1

Let's deploy Container Security, especially the Admission Controller part:

```sh
# Deploy Container Security
./deploy-container-security.sh
```

```sh
kubectl -n container-security get pods
```

```sh
NAME                                               READY   STATUS             RESTARTS   AGE
trendmicro-admission-controller-c6587bf86-v999w    1/1     Running            0          94s
trendmicro-runtime-protection-vgh7h                0/1     CrashLoopBackOff   3          94s
```

What you've now got is a running instance of the trendmicro-admission-controller within the namespace container-security. Please ignore the CrashLoopBackOff you're getting for the trendmicro-runtime-protection. This is caused by the reason, that we don't support the Ubuntu Bionic server version as of now.
The admission controller is already bound to your Smart Check instance whereby a pretty scrict policy is asssigned.

Test that with

```sh
# try to deploy nginx pod in its own namspace - fail if you set the policy to block
kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl create deployment --image=nginx --namespace nginx nginx
```

You will get an error in return, which tells you that the nginx image is unscanned and therefore not allowed to be deployed on your cluster.

```sh
error: failed to create deployment: admission webhook "trendmicro-admission-controller.container-security.svc" denied the request:
- unscannedImage violated in container(s) "nginx" (block).
```

Verify the event on your Cloud One console

## Lab 4 - Container Security #2

Now, we simulate a CI/CD pipeline which triggers a scan of the nginx on Smart Check. Do this with

```sh
export TARGET_IMAGE=nginx
export TARGET_IMAGE_TAG=latest

./scan-image.sh
```

So, let's try the deployment again...

```sh
kubectl create deployment --image=nginx --namespace nginx nginx
```

Uuups, still not working!

```sh
error: failed to create deployment: admission webhook "trendmicro-admission-controller.container-security.svc" denied the request:
- unscannedImage violated in container(s) "nginx" (block).
```

The reason for this is, that we scanned the nginx image within the cluster registry but we tried to deploy from docker hub. So we need to change our kubectl command a litle to tell kuberenetes to pull from our registry

```sh
kubectl create deployment --image=${REGISTRY_IP}:${REGISTRY_PORT}/nginx --namespace nginx nginx
```

Crap, now we get a different failure

```sh
error: failed to create deployment: admission webhook "trendmicro-admission-controller.container-security.svc" denied the request:
- vulnerabilities violates rule with properties { max-severity:medium } in container(s) "nginx" (block).
```

It tells us, that there are too many vulnerabilities. You can check on the console for this event as well.

For now, we simply switch to log events for vulnerabilities.

If you retry the last command you will be able to deploy our nginx.

## Lab 5 - Container Security #3

So, in real life kubernetes environments, there are typically namespaces you wish to exclude from Container Security. At the time of writing this lab, there is now way to easily configure that within the console of Cloud One, but you can achieve that with kubectl pretty easily.

Let's try that:

```sh
# test the shared registry running on the host
# pull hello-app:2.0 from Google and push it to the host registry
# deploy to the cluster
kubectl create namespace hello-app
kubectl --namespace hello-app run hello-app --image=gcr.io/google-samples/hello-app:2.0
```

The last command will fail, because the hello-app:2.0 wasn't scanned by Smart Check. To allow the deployment anyway (without scanning), we can exlude the namespace `hello-server-2` from the protection with Container Security.

Do this with

```sh
kubectl label namespace hello-app --overwrite ignoreAdmissionControl=ignore
```

The command above sets a label on the namespace, which you can view with

```sh
kubectl get ns --show-labels
```

```sh
NAME                 STATUS   AGE     LABELS
container-security   Active   90m     <none>
default              Active   113m    <none>
hello-app            Active   3m10s   ignoreAdmissionControl=ignore
ingress-nginx        Active   113m    app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx
kube-node-lease      Active   113m    <none>
kube-public          Active   113m    <none>
kube-system          Active   113m    ignoreAdmissionControl=ignore
local-path-storage   Active   113m    <none>
metallb-system       Active   113m    app=metallb,ignoreAdmissionControl=ignore
nginx                Active   86m     <none>
registry             Active   112m    <none>
smartcheck           Active   111m    ignoreAdmissionControl=ignore
```

As you can see, there are other namespaces already to be ignored (this was done by the deployment script already)

If you now retry the deployment you'll see that it's now working smoothly. Use that with caution :-)

```sh
kubectl --namespace hello-app run hello-app --image=gcr.io/google-samples/hello-app:2.0
```

## Tear Down

```sh
./down.sh
```
