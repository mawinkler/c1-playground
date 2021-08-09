# Playground

- [Playground](#playground)
  - [Requirements](#requirements)
  - [Configure](#configure)
  - [Start](#start)
  - [Tear Down](#tear-down)
  - [Add-On: Registry](#add-on-registry)
    - [Access Registry](#access-registry)
  - [Add-On: Cloud One Container Security](#add-on-cloud-one-container-security)
    - [Access Smart Check](#access-smart-check)
  - [Add-On: Scan-Image and Scan-Namespace](#add-on-scan-image-and-scan-namespace)
  - [Add-On: Prometheus & Grafana](#add-on-prometheus--grafana)
    - [Access Prometheus & Grafana](#access-prometheus--grafana)
  - [Add-On: Falco](#add-on-falco)
    - [Generate some events](#generate-some-events)
    - [Fun with privileged mode](#fun-with-privileged-mode)
    - [Access Falco UI](#access-falco-ui)
  - [Add-On: Krew](#add-on-krew)
  - [Add-On: Starboard](#add-on-starboard)
  - [Play with the Playground](#play-with-the-playground)
    - [Cluster Registry](#cluster-registry)
    - [Create a Deployment on Kubernetes - Echo Server #1](#create-a-deployment-on-kubernetes---echo-server-1)
    - [Create a Deployment on Kubernetes - Echo Server #2](#create-a-deployment-on-kubernetes---echo-server-2)
  - [Play with Container Security](#play-with-container-security)
    - [Continuous Compliance](#continuous-compliance)
    - [Namespace Exclusions](#namespace-exclusions)
    - [Explore](#explore)

Ultra fast and slim kubernetes playground.

Currently, the following services are integrated:

- Prometheus & Grafana
- Starboard
- Falco Runtime Security including Kubernetes Auditing
- Container Security
  - Smart Check
  - Deployment Admission Control, Continuous Compliance

## Requirements

***Tested on Ubuntu Bionic+, MacOS 10+ in progress***

In all of the three possible environments you're going to run a script called `tools.sh`. This will ensure you have the latest versions of

- `brew` (MacOS only),
- `docker` or `Docker for Mac`.
- `kubectl`,
- `kustomize`,
- `helm`,
- `kind`,
- `krew` and
- `kubebox`

installed.

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

Install required packages if not available. **After the installation continue in a new shell.**

```sh
./tools.sh
```

**IMPORTANT: Proceed in a new shell!**

</details>

<details>
<summary>MacOS</summary>

Install required packages if not available. **After the installation continue in a new shell.**

```sh
./tools.sh
```

Then, go to the `Preferences` of Docker for Mac, then `Resources` and `Advanced`. Ensure to have at least 4 CPUs and 12+ GB of Memory assigned to Docker.

**IMPORTANT: Proceed in a new shell!**

</details>

<details>
<summary>Cloud9</summary>

- Select Create Cloud9 environment
- Give it a name
- Choose “m5.large” or better for instance type and
- Ubuntu Server 18.04 LTS as the platform.
- For the rest take all default values and click Create environment

When it comes up, customize the environment by closing the welcome tab and lower work area, and opening a new terminal tab in the main work area.

Install required packages if not available. **After the installation continue in a new shell.**

```sh
./tools.sh
```

</details>

## Configure

First step is to clone the repo to your machine and second you create your personal configuration file.

```sh
git clone https://github.com/mawinkler/c1-playground.git
cd c1-playground
cp config.json.sample config.json
```

Typically you don't need to change anything here besides setting your api key for C1. If you're planning to use Cloud One Container Security you don't need an activation key for smart check, the api key is then sufficient.

```json
{
    ...
    "api_key": "YOUR KEY HERE",
    "activation_key": "YOUR KEY HERE"
}
```

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

> If running on a Cloud9, you now need to resize the disk of the EC2 instance20GB, execute:
>  
> ```sh
> ./resize.sh
> ```

The `up.sh` script later on will deploy a load balancer amongst other cluster components. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `X.X.255.1-X.X.255.250`. If the registry is deployed it will very likely be the second service requesting a load balancer IP, so typically it will get the `172.18.255.2` assignend which we define as an insecure registry for our local docker daemon.

To do this, create or modify `/etc/docker/daemon.json` to include a small subset probable ips for the registry.

```json
{"insecure-registries": ["172.18.255.1:5000","172.18.255.2:5000","172.18.255.3:5000"]}
```

Finally restart the docker daemon.

```sh
sudo systemctl restart docker
```

In the following step [Start](#start), you'll create the cluster, typically followed by creating the cluster registry. The last line of the output from `./deploy-registry.sh` shows you a docker login example. Try this. If it fails you need to verify the IP address range of the integrated load balancer that it matches the IPs from above. Typically, this is not required.

If it failed, we need to determine the network that is being used for the node ip pool. For that, we need to run `up.sh` and then query the nodes.

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

<details>
<summary>MacOS</summary>
Due to the fact, that there is no `docker0` bridge on MacOS, we need to use ingresses to enable access to services running on our cluster. To make this work, you need to modify your local `hosts`-file.

Change the line for 127.0.0.1 from

```txt
127.0.0.1 localhost
```

to

```txt
127.0.0.1 localhost playground-registry smartcheck grafana prometheus
```

</details>

<details>
<summary>Cloud9</summary>

You now need to resize the disk of the EC2 instance to 30GB, execute:

```sh
./resize.sh
```

The `up.sh` script later on will deploy a load balancer amongst other cluster components. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `X.X.255.1-X.X.255.250`. If the registry is deployed it will very likely be the second service requesting a load balancer IP, so typically it will get the `172.18.255.2` assignend which we define as an insecure registry for our local docker daemon.

To do this, create or modify `/etc/docker/daemon.json` to include a small subset probable ips for the registry.

```json
{"insecure-registries": ["172.18.255.1:5000","172.18.255.2:5000","172.18.255.3:5000"]}
```

Finally restart the docker daemon.

```sh
sudo systemctl restart docker
```

In the following step [Start](#start), you'll create the cluster, typically followed by creating the cluster registry. The last line of the output from `./deploy-registry.sh` shows you a docker login example. Try this. If it fails you need to verify the IP address range of the integrated load balancer that it matches the IPs from above. Typically, this is not required.

If it failed, we need to determine the network that is being used for the node ip pool. For that, we need to run `up.sh` and then query the nodes.

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

## Start

Simply run

```sh
./up.sh
```

## Tear Down

```sh
./down.sh
```

## Add-On: Registry

To deploy the registry run:

```sh
./deploy-registry.sh
```

### Access Registry 

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

A file called `services` is either created or updated with the link and the credentials to connect to the registry.

Example:

- `Registry login with: echo trendmicro | docker login https://172.18.255.1:5000 --username admin --password-stdin`

</details>

<details>
<summary>MacOS</summary>

A file called `services` is either created or updated with the link and the credentials to connect to the registry.

Example:

- `Registry login with: echo trendmicro | docker login https://playground-registry:443 --username admin --password-stdin`

</details>

<details>
<summary>Cloud9</summary>

A file called `services` is either created or updated with the link and the credentials to connect to the registry.

Example:

- `Registry login with: echo trendmicro | docker login https://172.18.255.1:5000 --username admin --password-stdin`

</details>

## Add-On: Cloud One Container Security

To deploy Container Security run:

```sh
./deploy-smartcheck.sh
./deploy-container-security.sh
```

### Access Smart Check

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Smart check UI on: https://192.168.1.121:8443 w/ admin/trendmicro`

</details>

<details>
<summary>MacOS</summary>

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Smart check UI on: https://smartcheck:443 w/ admin/trendmicro`

</details>

<details>
<summary>Cloud9</summary>

If working on a Cloud9 environment you need to adapt the security group of the corresponding EC2 instance to enable access from your browwer. To share Smart Check over the internet, follow the steps below.

1. Query the public IP of your Cloud9 instance with
   ```sh
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```
2. In the IDE for the environment, on the menu bar, choose your user icon, and then choose Manage EC2 Instance
3. Select the security group associated to the instance and select Edit inbound rules.
4. Add an inbound rule for the `proxy_listen_port` configured in you config.json (default: 8443) and choose Source Anywhere
5. Depending on the currently configured Network ACL you might need to add a rule to allow ingoing traffic on the same port. To do this go to the VPC within the Cloud9 instance is running and proceed to the associated Main network ACL.
6. Ensure that an inbound rule is set which allows traffic on the `proxy_listen_port`. If not, click on `Edit inbound rules` and add a rule with a low Rule number, Custom TCP, Port range 8443 (or your configured port), Source 0.0.0.0/0 and Allow.

You should now be able to connect to Smart Check on the public ip of your Cloud9 with your configured port.

</details>

## Add-On: Scan-Image and Scan-Namespace

The two scripts `scan-image.sh` and `scan-namespace.sh` do what you would expect. Running

```sh
./scan-image.sh nginx:latest
```

starts an asynchronous scan of the latest version of nginx. The scan will run on Smart Check, but you are immedeately back in the shell. To access the scan results either use the UI or API of Smart Check.

If you add the flag `-s` the scan will be synchronous, so you get the scan results directly in your shell.

```sh
./scan-image.sh -s nginx:latest
```

```json
...
{ critical: 6,
  high: 39,
  medium: 40,
  low: 13,
  negligible: 2,
  unknown: 3 }
```

The script

```sh
./scan-namespace.sh
```

scans all used images within the current namespace. Maybe do a `kubectl config set-context --current --namespace <NAMESPACE>` beforehand to select the namespace to be scanned.

## Add-On: Prometheus & Grafana

By running `deploy-prometheus-grafana.sh` you'll get a fully functional and preconfigured Prometheus and Grafana instance on the playground.

The following additional scrapers are configured:

- [api-collector](https://github.com/mawinkler/api-collector)
- [Falco]((#add-on-falco))
- smartcheck-metrics

### Access Prometheus & Grafana

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

By default, the Prometheus UI is on port 8081, Grafana on port 8080.

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Prometheus UI on: http://192.168.1.121:8081`
- `Grafana UI on: http://192.168.1.121:8080 w/ admin/trendmicro`

</details>

<details>
<summary>MacOS</summary>

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Prometheus UI on: http://prometheus`
- `Grafana UI on: http://grafana w/ admin/trendmicro`

</details>

<details>
<summary>Cloud9</summary>

See: [Access Smart Check (Cloud9)](#access-smart-check-cloud9)

</details>

## Add-On: Falco

The deployment of Falco runtime security is very straigt forward with the playground. Simply execute the script `deploy-falco.sh`, everything else is prepared.

> Note for MacOS: Falco is currently unsupported on MacOS

```sh
./deploy-falco.sh
```

The web-ui is available on <http://HOSTNAME:8082/ui> (default)

To test the k8s auditing try to create a configmap:

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  ui.properties: |
    color.good=purple
    color.bad=yellow
    allow.textmode=true
  access.properties: |
    aws_access_key_id = AKIAXXXXXXXXXXXXXXXX
    aws_secret_access_key = 1CHPXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
kind: ConfigMap
metadata:
  name: awscfg
EOF
```

Relevant kind configuration is already done within the `up.sh` script.

Falco is integrated with Prometheus and Grafana as well. A Dashboard is available for import with the ID 11914.

![alt text](images/falco-grafana.png "Grafana Dashboard")

### Generate some events

```sh
docker run -it --rm falcosecurity/event-generator run syscall --loop
```

### Fun with privileged mode

```sh
function shell () {
  kubectl run shell --restart=Never -it --image krisnova/hack:latest \
  --rm --attach \
  --overrides \
        '{
          "spec":{
            "hostPID": true,
            "containers":[{
              "name":"scary",
              "image": "krisnova/hack:latest",
	      "imagePullPolicy": "Always",
              "stdin": true,
              "tty": true,
              "command":["/bin/bash"],
	      "nodeSelector":{
		"dedicated":"master" 
	      },
              "securityContext":{
                "privileged":true
              }
            }]
          }
        }'
}
```

You can paste this into a new file `shell.sh` and source the file.

```sh
source shell.sh
```

Then you can type the following to demonstrate a privilege escalation in Kubernetes.

```sh
shell
```

If you don't see a command prompt, try pressing enter.

```sh
root@shell:/# nsenter -t 1 -m -u -i -n bash
root@playground-control-plane:/# 
```

Doing this takes advantage of a well known security exploit in Kubernetes.

### Access Falco UI

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

By default, the Falco UI is on port 8082.

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Falco UI on: http://192.168.1.121:8082/ui/#/`

</details>

<details>
<summary>MacOS</summary>

***Currently not supported***

</details>

<details>
<summary>Cloud9</summary>

See: [Access Smart Check (Cloud9)](#access-smart-check-cloud9)

</details>

## Add-On: Krew

Krew is a tool that makes it easy to use kubectl plugins. Krew helps you discover plugins, install and manage them on your machine. It is similar to tools like apt, dnf or brew. Today, over 130 kubectl plugins are available on Krew.

Eample usage:

```sh
kubectl krew list
kubectl krew install tree
```

The tree command is a kubectl plugin to browse Kubernetes object hierarchies as a tree.

```sh
kubectl tree node playground-control-plane -A
```

## Add-On: Starboard

Fundamentally, Starboard gathers security data from various Kubernetes security tools into Kubernetes Custom Resource Definitions (CRD). These extend the Kubernetes APIs so that users can manage and access security reports through the Kubernetes interfaces, like kubectl.

To deploy it, run

```sh
./deploy-starboard.sh
```

```sh
kubectl logs -f -n starboard deployment/starboard-starboard-operator
```

Workload Scanning

```sh
kubectl get job -n starboard
kubectl get vulnerabilityreports --all-namespaces -o wide
kubectl get configauditreports --all-namespaces -o wide
```

Infrastructure Scanning - The operator discovers also Kubernetes nodes and runs CIS Kubernetes Benchmark checks on each of them. The results are stored as CISKubeBenchReport objects.

```sh
kubectl get ciskubebenchreports -o wide
```

Inspect any of the reports run something like this

```sh
kubectl describe vulnerabilityreport -n kube-system daemonset-kindnet-kindnet-cni
```

## Play with the Playground

### Cluster Registry

```sh
# pull hello-app:1.0 from Google and push it to the cluster registry
# verify w/ curl
REGISTRY_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' config.json)"
REGISTRY_NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' config.json)"
REGISTRY_USERNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .username' config.json)"
REGISTRY_PASSWORD="$(jq -r '.services[] | select(.name=="playground-registry") | .password' config.json)"
REGISTRY_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)"
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

### Create a Deployment on Kubernetes - Echo Server #1

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

### Create a Deployment on Kubernetes - Echo Server #2

```sh
# instant deployment and scale an echo-server
kubectl create deployment echo --image=inanimate/echo-server
kubectl scale deployment echo --replicas=3
kubectl get deployments
kubectl expose deployment echo --port=8080 --type LoadBalancer

echo Try: curl $(kubectl --namespace default get svc echo \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080
```

## Play with Container Security

First, deploy Cloud One Container Security

```sh
./deploy-container-security.sh
```

```sh
kubectl -n container-security get pods
```

```sh
NAME                                               READY   STATUS             RESTARTS   AGE
trendmicro-admission-controller-67bd7d947c-xk275   1/1     Running        0          2d18h
trendmicro-oversight-controller-c7ff9954b-qzfnk    2/2     Running        0          2d18h
trendmicro-usage-controller-678b76fc4b-vgrsb       2/2     Running        0          2d18h
```

What you've now got is running instances of the admission-, oversight- and usage-controllers within the namespace container-security. The admission controller is already bound to your Smart Check instance whereby a pretty scrict policy is asssigned.

Try it:

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

Do trigger a scan of the image

```sh
./scan-image.sh nginx latest
```

The script above downloads the `nginx`, pushes it to our internal cluster registry and initiates a regular scan (not a pre-registry-scan).

So, let's try the deployment again...

```sh
kubectl create deployment --image=nginx --namespace nginx nginx
```

Uuups, still not working!

```sh
error: failed to create deployment: admission webhook "trendmicro-admission-controller.container-security.svc" denied the request:
- unscannedImage violated in container(s) "nginx" (block).
```

The reason for this is, that we scanned the nginx image within the cluster registry but we tried to deploy from docker hub.

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

Modify the line `spec.templates.spec.containers.image` to point to the internal registry as shown above. Additionally add the `spec.templates.spec.imagePullSecrets`block.

Now, we need to create an image pull secret within the nginx namespace, if it does not already exists from the previous tests

```sh
kubectl create secret docker-registry regcred --docker-server=${REGISTRY_IP}:${REGISTRY_PORT} --docker-username=${REGISTRY_USERNAME} --docker-password=${REGISTRY_PASSWORD} --docker-email=info@mail.com --namespace nginx
```

Finally, create the deployment

```sh
kubectl -n nginx apply -f nginx.yaml
```

Crap, now we get a different failure

```sh
Error from server: error when creating "nginx.yaml": admission webhook "trendmicro-admission-controller.container-security.svc" denied the request: 
- vulnerabilities violates rule with properties { max-severity:medium } in container(s) "nginx" (block).
```

It tells us, that there are too many vulnerabilities. You can check on the console for this event as well. If you don't get the above error, then the image got fixed in the meanwhile :-).

For now, we simply switch to log events for vulnerabilities.

If you retry the last command you will be able to deploy our nginx.

Now, create a service and try, if we can reach the nginx

```sh
kubectl -n nginx expose deployment nginx --type=LoadBalancer --name=nginx --port 80

kubectl -n nginx get service
```

```sh
NAME    TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
nginx   LoadBalancer   10.96.194.46   172.18.255.10   80:32168/TCP   79s
```

```sh
curl 172.18.255.10
```

Your should get some html in return.

### Continuous Compliance

We do know, that our nginx is vulnerable (at least, mostly it is). So, we have it running now which is a good chance to try out our continuous compliance functionality. Container Security is rescanning the compliance state every five minutes according to our overrides file.

```yaml
cloudOne:
  oversight:
    syncPeriod: 600s
```

Let's configure the continuous policy in cloud one to isolate vulnerable images.

For this, go to the continuous section of our playground policy and set

***Isolate images with vulnerabilities whose severity is high or higher***

Then, go to the deployment section and set

***Block images with vulnerabilities whose severity is high or higher***

After less or equal than five minutes, container security should have created an isolating network policy which you can display with

```sh
kubectl -n nginx get networkpolicies
```

```sh
NAME                                  POD-SELECTOR                   AGE
trendmicro-oversight-isolate-policy   trendmicro-cloud-one=isolate   25s
```

```sh
kubectl -n nginx edit networkpolicies trendmicro-oversight-isolate-policy
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  creationTimestamp: "2021-07-30T13:31:40Z"
  generation: 1
  labels:
    app.kubernetes.io/instance: container-security
  name: trendmicro-oversight-isolate-policy
  namespace: nginx
  resourceVersion: "7665"
  uid: 2825fcb6-f09c-40f5-84e9-f3404fbe2dd9
spec:
  podSelector:
    matchLabels:
      trendmicro-cloud-one: isolate
  policyTypes:
  - Ingress
  - Egress
```

An "empty" Ingress / Egress definition basically isolates the resource.

If you now repeat the previous curl

```sh
curl 172.18.255.10
```

It should time out.

> Note: The isolation of workload on a kubernetes cluster requires a pod network, which does support network policies. Neither the default cni `kindnet` on kind clusters nor `flannel` do support that. That's the reason why the playground uses `calico` as the pod network.

### Namespace Exclusions

Ensure to have the block rule `Images that are not scanned` applied to your Container Control policy, as above,

Create a namespace for a different pod and try to deploy it

```sh
export TARGET_IMAGE=busybox
export TARGET_IMAGE_TAG=latest

kubectl create ns ${TARGET_IMAGE}
kubectl run -n ${TARGET_IMAGE} --image=${TARGET_IMAGE} ${TARGET_IMAGE}
```

The above should fail.

If you want to exclude a namespace from admission control, label it

```sh
kubectl label ns ${TARGET_IMAGE} ignoreAdmissionControl=true --overwrite

kubectl get ns --show-labels ${TARGET_IMAGE}
```

You should see:

```sh
NAME      STATUS   AGE   LABELS
busybox   Active   23s   ignoreAdmissionControl=true,kubernetes.io/metadata.name=busybox
```

Now rerun the run command

```sh
kubectl run -n ${TARGET_IMAGE} --image=${TARGET_IMAGE} ${TARGET_IMAGE}
```

This should now work, because Container Control is ignoring the labeled namespace.

### Explore

The potentially most interesting part on your cluster (in reagards Container Control) is the ValidatingWebhookConfiguration. Review and understand it.

```sh
kubectl get ValidatingWebhookConfiguration
```

```sh
NAME                                                 WEBHOOKS   AGE
admission-controller-trendmicro-container-security   1          8m1s
```

```sh
kubectl edit ValidatingWebhookConfiguration admission-controller-trendmicro-container-security
```

Inspect the yaml

```yaml
...
webhooks:
- admissionReviewVersions:
  - v1
  - v1beta1
  clientConfig:
    caBundle: LS0tLS1CRUdJTiBDRVJUSUZJQ0FUR...0tLQo=
    service:
      name: trendmicro-admission-controller
      namespace: container-security
      path: /api/validate
      port: 443
  failurePolicy: Ignore
  matchPolicy: Equivalent
  name: trendmicro-admission-controller.container-security.svc
  namespaceSelector:
    matchExpressions:
    - key: ignoreAdmissionControl
      operator: DoesNotExist
  objectSelector: {}
  rules:
  - apiGroups:
    - '*'
    apiVersions:
    - '*'
    operations:
    - '*'
    resources:
    - pods
    - pods/ephemeralcontainers
    - replicasets
    - replicationcontrollers
    - deployments
    - statefulsets
    - daemonsets
    - jobs
    - cronjobs
    scope: Namespaced
  sideEffects: None
  timeoutSeconds: 30
```

A little explanation for the above:

- `clientConfig` defines, which service endpoint is contacted by kubernetes.
- `namespaceSelector` specifies the label, which when set on a namespace, skips the admission validation
- `rules` defines, for which apiGroups, apiVersions, operations and resources kubernetes will query our admission controller

So, if everything matches, kubernetes will query our service which will then send a request to Cloud One where the request is checked against the configured policy for this cluster. More or less, we're only responding with an `allow` or `deny` and a little context which includes the reason for our decission.

To see all the available configuration options you can query the helm chart with

```sh
helm inspect values https://github.com/trendmicro/cloudone-admission-controller-helm/archive/master.tar.gz
```
