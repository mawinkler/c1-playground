# Play with the Playground (on Linux & Cloud9)

- [Play with the Playground (on Linux & Cloud9)](#play-with-the-playground-on-linux--cloud9)
  - [Cluster Registry](#cluster-registry)
  - [Create a Deployment on Kubernetes - Echo Server #1](#create-a-deployment-on-kubernetes---echo-server-1)
  - [Create a Deployment on Kubernetes - Echo Server #2](#create-a-deployment-on-kubernetes---echo-server-2)
  - [Play with Container Security Admission Control](#play-with-container-security-admission-control)
  - [Play with Container Security Continuous Compliance](#play-with-container-security-continuous-compliance)
  - [Namespace Exclusions](#namespace-exclusions)
  - [Explore](#explore)

Ensure to have run `up.sh` and `deploy-registry.sh` according to the [README.md](../README.md). If you already deployed additional components, please restart from scratch (`down.sh`, `up.sh`, `deploy-registry.sh`).

## Cluster Registry

```sh
$ # pull hello-app:1.0 from Google and push it to the cluster registry
$ # verify w/ curl
$ REGISTRY_NAME="$(jq -r '.services[] | select(.name=="playground-registry") | .name' config.json)" && \
  REGISTRY_NAMESPACE="$(jq -r '.services[] | select(.name=="playground-registry") | .namespace' config.json)" && \
  REGISTRY_USERNAME="$(jq -r '.services[] | select(.name=="playground-registry") | .username' config.json)" && \
  REGISTRY_PASSWORD="$(jq -r '.services[] | select(.name=="playground-registry") | .password' config.json)" && \
  REGISTRY_PORT="$(jq -r '.services[] | select(.name=="playground-registry") | .port' config.json)" && \
  REGISTRY_IP=$(kubectl get svc -n ${REGISTRY_NAMESPACE} ${REGISTRY_NAME} \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

$ echo ${REGISTRY_PASSWORD} | docker login https://${REGISTRY_IP}:${REGISTRY_PORT} --username ${REGISTRY_USERNAME} --password-stdin

$ docker pull gcr.io/google-samples/hello-app:1.0
$ docker tag gcr.io/google-samples/hello-app:1.0 ${REGISTRY_IP}:${REGISTRY_PORT}/hello-app:1.0
$ docker push ${REGISTRY_IP}:${REGISTRY_PORT}/hello-app:1.0
$ curl -k https://${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}@${REGISTRY_IP}:${REGISTRY_PORT}/v2/_catalog
```

You should get

```json
{"repositories":["hello-app"]}
```

## Create a Deployment on Kubernetes - Echo Server #1

```sh
$ # create a pull secret and deployment
$ kubectl create secret docker-registry regcred --docker-server=${REGISTRY_IP}:${REGISTRY_PORT} --docker-username=${REGISTRY_USERNAME} --docker-password=${REGISTRY_PASSWORD} --docker-email=info@mail.com

$ cat <<EOF | kubectl apply -f -
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

$ echo Try: curl $(kubectl --namespace default get svc hello-server \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080
```

You should get

```
Hello, world!
Version: 1.0.0
Hostname: hello-server-6488746978-vvtdx
```

## Create a Deployment on Kubernetes - Echo Server #2

```sh
$ # instant deployment and scale an echo-server
$ kubectl create deployment echo --image=inanimate/echo-server
$ kubectl scale deployment echo --replicas=3
$ kubectl get deployments
$ kubectl expose deployment echo --port=8080 --type LoadBalancer

echo Try: curl $(kubectl --namespace default get svc echo \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080
```

## Play with Container Security Admission Control

First, deploy Cloud One Container Security

```sh
$ ./deploy-smartcheck.sh
$ ./deploy-container-security.sh
```

```sh
$ kubectl -n container-security get pods
```

```
NAME                                               READY   STATUS             RESTARTS   AGE
trendmicro-admission-controller-67bd7d947c-xk275   1/1     Running        0          2d18h
trendmicro-oversight-controller-c7ff9954b-qzfnk    2/2     Running        0          2d18h
trendmicro-usage-controller-678b76fc4b-vgrsb       2/2     Running        0          2d18h
```

What you've now got is running instances of the admission-, oversight- and usage-controllers within the namespace container-security. The admission controller is already bound to your Smart Check instance whereby a pretty scrict policy is asssigned.

Try it:

```sh
$ # try to deploy nginx pod in its own namspace - fail if you set the policy to block
$ kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f - > /dev/null
$ kubectl create deployment --image=nginx --namespace nginx nginx
```

You will get an error in return, which tells you that the nginx image is unscanned and therefore not allowed to be deployed on your cluster.

```
error: failed to create deployment: admission webhook "trendmicro-admission-controller.container-security.svc" denied the request: 
- unscannedImage violated in container(s) "nginx" (block).
```

Do trigger a scan of the image

```sh
$ ./scan-image.sh nginx:latest -s
```

The script above downloads the `nginx`, pushes it to our internal cluster registry and initiates a regular scan (not a pre-registry-scan).

So, let's try the deployment again...

```sh
$ kubectl create deployment --image=nginx --namespace nginx nginx
```

Uuups, still not working!

```
error: failed to create deployment: admission webhook "trendmicro-admission-controller.container-security.svc" denied the request:
- unscannedImage violated in container(s) "nginx" (block).
```

The reason for this is, that we scanned the nginx image within the cluster registry but we tried to deploy from docker hub.

Now the nginx was scanned, we need to change the deployment manfest for it, that it is pulled from our internal registry and not docker hub.

```
$ kubectl create deployment --image=nginx --namespace nginx --dry-run=client nginx -o yaml > nginx.yaml
```

Now edit the `nginx.yaml`

```sh
$ vi nginx.yaml
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
$ kubectl create secret docker-registry regcred --docker-server=${REGISTRY_IP}:${REGISTRY_PORT} --docker-username=${REGISTRY_USERNAME} --docker-password=${REGISTRY_PASSWORD} --docker-email=info@mail.com --namespace nginx
```

Finally, create the deployment

```sh
$ kubectl -n nginx apply -f nginx.yaml
```

Crap, now we get a different failure

```
Error from server: error when creating "nginx.yaml": admission webhook "trendmicro-admission-controller.container-security.svc" denied the request: 
- vulnerabilities violates rule with properties { max-severity:medium } in container(s) "nginx" (block).
```

It tells us, that there are too many vulnerabilities. You can check on the console for this event as well. If you don't get the above error, then the image got fixed in the meanwhile :-).

For now, we simply switch to log events for vulnerabilities.

If you retry the last command you will be able to deploy our nginx.

Now, create a service and try, if we can reach the nginx

```sh
$ kubectl -n nginx expose deployment nginx --type=LoadBalancer --name=nginx --port 80
$ kubectl -n nginx get service
```

```
NAME    TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
nginx   LoadBalancer   10.96.194.46   172.18.255.10   80:32168/TCP   79s
```

```sh
$ curl 172.18.255.10
```

Your should get some html in return.

## Play with Container Security Continuous Compliance

We do know, that our nginx is vulnerable (at least, mostly it is). So, we have it running now which is a good chance to try out our continuous compliance functionality. Container Security is rescanning the compliance state every ten minutes according to our overrides file.

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

After typically less or equal five minutes, container security should have created an isolating network policy which you can display with

```sh
$ kubectl -n nginx get networkpolicies
```

```
NAME                                  POD-SELECTOR                   AGE
trendmicro-oversight-isolate-policy   trendmicro-cloud-one=isolate   25s
```

```sh
$ kubectl -n nginx edit networkpolicies trendmicro-oversight-isolate-policy
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
$ curl 172.18.255.10
```

It should time out.

> Note: The isolation of workload on a kubernetes cluster requires a pod network, which does support network policies. Neither the default cni `kindnet` on kind clusters nor `flannel` do support that. That's the reason why the playground uses `calico` as the pod network.

## Namespace Exclusions

Ensure to have the block rule `Images that are not scanned` applied to your Container Control policy, as above,

Create a namespace for a different pod and try to deploy it

```sh
$ export TARGET_IMAGE=busybox
$ export TARGET_IMAGE_TAG=latest
$ kubectl create ns ${TARGET_IMAGE}
$ kubectl run -n ${TARGET_IMAGE} --image=${TARGET_IMAGE} ${TARGET_IMAGE}
```

The above should fail.

If you want to exclude a namespace from admission control, label it

```sh
$ kubectl label ns ${TARGET_IMAGE} ignoreAdmissionControl=true --overwrite
$ kubectl get ns --show-labels ${TARGET_IMAGE}
```

You should see:

```
NAME      STATUS   AGE   LABELS
busybox   Active   23s   ignoreAdmissionControl=true,kubernetes.io/metadata.name=busybox
```

Now rerun the run command

```sh
$ kubectl run -n ${TARGET_IMAGE} --image=${TARGET_IMAGE} ${TARGET_IMAGE}
```

This should now work, because Container Control is ignoring the labeled namespace.

## Explore

The potentially most interesting part on your cluster (in reagards Container Control) is the ValidatingWebhookConfiguration. Review and understand it.

```sh
$ kubectl get ValidatingWebhookConfiguration
```

```
NAME                                                 WEBHOOKS   AGE
admission-controller-trendmicro-container-security   1          8m1s
```

```sh
$ kubectl edit ValidatingWebhookConfiguration admission-controller-trendmicro-container-security
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
$ helm inspect values https://github.com/trendmicro/cloudone-admission-controller-helm/archive/master.tar.gz
```
