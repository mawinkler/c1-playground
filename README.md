# Playground

- [Playground](#playground)
  - [Requirements](#requirements)
  - [Configure](#configure)
  - [Start Linux](#start-linux)
  - [Start MacOS (in progress)](#start-macos-in-progress)
  - [Tear Down](#tear-down)
  - [Tests](#tests)
    - [Registry](#registry)
    - [Host Registry](#host-registry)
    - [Container Security](#container-security)

Ultra fast and slim kubernetes playground

## Requirements

*Tested on Ubuntu Bionic+ only, MacOS 10+ in progress*

<details>
<summary>Ubuntu</summary>

Install required packages if not available. **After the installation continue in a new shell.**

```sh
# install packages
sudo apt update
sudo apt install -y jq apt-transport-https gnupg2 curl nginx

# install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
ME=$(whoami)
sudo usermod -aG docker ${ME}

# kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.9.0/kind-linux-amd64
chmod +x ./kind
sudo mv kind /usr/local/bin/
```

**IMPORTANT: Proceed in a new shell!**
</details>

<details>
<summary>Cloud9 w/ Ubuntu</summary>

- Select Create Cloud9 environment
- Give it a name
- Choose “m5.large” or better for instance type and
- Ubuntu Server 18.04 LTS as the platform.
- For the rest take all default values and click Create environment

When it comes up, customize the environment by closing the welcome tab and lower work area, and opening a new terminal tab in the main work area.

Install required packages if not available. **After the installation continue in a new shell.**

```sh
# install packages
sudo apt update
sudo apt install -y jq apt-transport-https gnupg2 curl nginx

# install docker
# curl -fsSL https://get.docker.com -o get-docker.sh
# sudo sh get-docker.sh
# ME=$(whoami)
# sudo usermod -aG docker ${ME}

# kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.9.0/kind-linux-amd64
chmod +x ./kind
sudo mv kind /usr/local/bin/
```

Since the disk size in Cloud9 environments is limited, you need to increase the size of the local volume to 20GB, execute:

```sh
./resize.sh
```

</details>

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

The `up.sh` script will deploy a load balancer amongst others. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `X.X.255.1-X.X.255.250`. If the registry is deployed it will very likely be the second service requesting a load balancer IP, so typically it will get the `172.18.255.2` assignend which we define as an insecure registry for our local docker daemon.

To do this, create or modify `/etc/docker/daemon.json` to include a small subset probable ips for the registry.

```json
{"insecure-registries": ["172.18.255.1:5000","172.18.255.2:5000","172.18.255.3:5000"]}
```

Finally restart the docker daemon.

```sh
sudo systemctl restart docker
```

In the following step, you'll create the cluster. The last line of the output shows you a docker login example. Try this. If it fails you need to verify the IP address range of the integrated load balancer that it matches the IPs from above. Typically, this is not required.

<details>
<summary>IP fix</summary>

At this point we need to determine the network that is being used for the node ip pool. For that, we need to run `up.sh` and then query the nodes.

```sh
kubectl get nodes -o json | jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address'
```

```sh
172.18.0.2
```

Adapt the file `/etc/docker/daemon.json` accordingly. Then

```sh
./stop.sh
sudo systemctl restart docker
```

</details>

## Start Linux

```sh
./up.sh
./deploy-smartcheck.sh
./deploy-proxy.sh
```

If you want to deploy Container Security, run

```sh
./deploy-container-security.sh
```

> If working on a Cloud9 environment you need to adapt the security group of the corresponding EC2 instance to enable access from your browwer

<details>
<summary>Share Smart Check over the internet </summary>

1. Query the public IP of your Cloud9 instance with
   ```sh
   curl curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```
2. In the IDE for the environment, on the menu bar, choose your user icon, and then choose Manage EC2 Instance
3. Select the security group associated to the instance and select Edit inbound rules.
4. Add an inbound rule for the `proxy_listen_port` configured in you config.json (default: 8443) and choose Source Anywhere
5. Depending on the currently configured Network ACL you might need to add a rule to allow ingoing traffic on the same port. To do this go to the VPC within the Cloud9 instance is running and proceed to the associated Main network ACL.
6. Ensure that an inbound rule is set which allows traffic on the `proxy_listen_port`. If not, click on `Edit inbound rules` and add a rule with a low Rule number, Custom TCP, Port range 8443 (or your configured port), Source 0.0.0.0/0 and Allow.

You should now be able to connect to Smart Check on the public ip with your configured port.

</details>

## Start MacOS (in progress)

Support for MacOS is still in progress.

```sh
./up.sh
./deploy-registry.sh
./deploy-smartcheck.sh
```

```sh
kubectl port-forward -n smartcheck svc/proxy 1443:443
```

Access Smart Check with browser `https://localhost:1443`

## Tear Down

```sh
./down.sh
```

## Tests

### Registry

```sh
# pull hello-app:1.0 from Google and push it to the cluster registry
# verify w/ curl
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

Echo Server

```sh
# instant deployment and scale an echo-server
kubectl create deployment echo --image=inanimate/echo-server
kubectl scale deployment echo --replicas=3
kubectl get deployments
kubectl expose deployment echo --port=8080 --type LoadBalancer

echo Try: curl $(kubectl --namespace default get svc echo \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080
```

### Host Registry

```sh
# test the shared registry running on the host
# pull hello-app:2.0 from Google and push it to the host registry
# deploy to the cluster
docker pull gcr.io/google-samples/hello-app:2.0
docker tag gcr.io/google-samples/hello-app:2.0 localhost:5000/hello-app:2.0
docker push localhost:5000/hello-app:2.0
kubectl create deployment hello-server-2 --image=localhost:5000/hello-app:2.0

echo Try: kubectl get pods | grep hello-server-2
```

### Container Security

First, deploy Cloud One Container Security

```sh
./deploy-container-security.sh
```

Try it:

```sh
# try to deploy nginx pod in its own namspace - fail if you set the policy to block
kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl create deployment --image=nginx --namespace nginx nginx
```

Ensure to have `deploy-smartcheck.sh` run.

Do trigger a scan of an image

```sh
export TARGET_IMAGE=nginx
export TARGET_IMAGE_TAG=latest

./scan-image.sh
```

Now the nginx was scanned, we need to change the deployment manfest for it, that it is pulled from our internal registry and not docker hub.

```sh
kubectl create deployment --image=nginx --namespace nginx --dry-run=client nginx -o yaml > nginx.yaml
```

Now edit the `nginx.yaml`

```sh
vi nginx.yaml
```

```yaml
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
      - image: 172.18.255.1:5000/nginx:latest
        name: nginx
        resources: {}
      imagePullSecrets:
      - name: regcred
status: {}
```

Modify the line `spec.templates.spec.containers.image` to point to the internal registry as shown above

Now, we need to create an image pull secret within the nginx namespace.

```sh
kubectl create secret docker-registry regcred --docker-server=${REGISTRY_IP}:${REGISTRY_PORT} --docker-username=${REGISTRY_USERNAME} --docker-password=${REGISTRY_PASSWORD} --docker-email=info@mail.com
```

Finally, create the deployment

```sh
kubectl apply -f nginx.yaml
```
