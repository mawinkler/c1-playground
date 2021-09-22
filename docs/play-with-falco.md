# Play with Falco & Container Security

- [Play with Falco & Container Security](#play-with-falco--container-security)
  - [Plays for Falco](#plays-for-falco)
    - [Networking](#networking)
      - [(PG-NET) Kubernetes Outbound Connection](#pg-net-kubernetes-outbound-connection)
    - [KShell](#kshell)
      - [(PG-KSHELL) Process started in kshell container](#pg-kshell-process-started-in-kshell-container)
      - [(PG-KSHELL) File or directory created in kshell container](#pg-kshell-file-or-directory-created-in-kshell-container)
    - [Dangerous Things](#dangerous-things)
      - [(PG-IG) Information gathering detected](#pg-ig-information-gathering-detected)
      - [(PG-SHELL) Attach/Exec Pod with Terminal User shell in container](#pg-shell-attachexec-pod-with-terminal-user-shell-in-container)
      - [(PG-SHELL) Attach/Exec Pod with Terminal Root shell in container](#pg-shell-attachexec-pod-with-terminal-root-shell-in-container)
      - [(PG-ROOT) Container Run as Root User](#pg-root-container-run-as-root-user)
    - [Integrity Monitoring in Containers](#integrity-monitoring-in-containers)
      - [(PG-IMC) Detect New File](#pg-imc-detect-new-file)
      - [(PG-IMC) Detect New Directory](#pg-imc-detect-new-directory)
      - [(PG-IMC) Detect File Permission or Ownership Change](#pg-imc-detect-file-permission-or-ownership-change)
      - [(PG-IMC) Detect Directory Change](#pg-imc-detect-directory-change)
    - [Integrity Monitoring on Host and Containers](#integrity-monitoring-on-host-and-containers)
      - [(PG-IM) Kernel Module Modification](#pg-im-kernel-module-modification)
      - [(PG-IM) Node Created in Filesystem](#pg-im-node-created-in-filesystem)
      - [(PG-IM) Listen on New Port](#pg-im-listen-on-new-port)
    - [Admin Activities](#admin-activities)
      - [(PG-ADM) Detect su or sudo](#pg-adm-detect-su-or-sudo)
      - [(PG-ADM) Package Management Launched](#pg-adm-package-management-launched)
    - [SSH](#ssh)
      - [(PG-SSH) Inbound SSH Connection](#pg-ssh-inbound-ssh-connection)
      - [(PG-SSH) Outbound SSH Connection](#pg-ssh-outbound-ssh-connection)
    - [Miscellaneous](#miscellaneous)
      - [(PG-KUBECTL) K8s Vulnerable Kubectl Copy](#pg-kubectl-k8s-vulnerable-kubectl-copy)

## Plays for Falco

These examples are based on the default Falco ruleset and the additional rules provided by the playground.

### Networking

#### (PG-NET) Kubernetes Outbound Connection

Triggers, if a container is initiating an outbound network communication via TCP or UDP.

```sh
kubectl exec -it -n nginx nginx-6799fc88d8-n5tdd -- /bin/bash
root@nginx-6799fc88d8-n5tdd:/# curl www.google.com
```

### KShell

#### (PG-KSHELL) Process started in kshell container

Triggers, if any process is run in the kshell pod

```sh
kubectl run -it --image=ubuntu kshell --restart=Never --labels=kshell=true --rm -- /bin/bash
root@kshell:/# tail /var/log/bootstrap.log 
```

#### (PG-KSHELL) File or directory created in kshell container

Triggers, if a file or directory is created in the kshell pod

```sh
kubectl run -it --image=ubuntu kshell --restart=Never --labels=kshell=true --rm -- /bin/bash
root@kshell:/# touch foo.txt
root@kshell:/# mkdir bar
```

### Dangerous Things

#### (PG-IG) Information gathering detected

Triggers, if one of the named tools (whoami, nmap, racoon) is run inside a container.

```sh
kubectl run -it busybox --image busybox -- /bin/sh
/ # whoami
```

#### (PG-SHELL) Attach/Exec Pod with Terminal User shell in container

This rule triggers, if one attaches / executes a shell in a container not running as root.

```sh
cat <<EOF | kubectl apply -f - 
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: sec-ctx-demo
    image: busybox
    command: [ "sh", "-c", "sleep 1h" ]
    securityContext:
      allowPrivilegeEscalation: false
EOF
```

and

```sh
kubectl exec -it security-context-demo -- /bin/sh
```

#### (PG-SHELL) Attach/Exec Pod with Terminal Root shell in container

This rule triggers, if one attaches / executes a shell in a container not running as root.

```sh
kubectl create namespace nginx
kubectl -n nginx create deployment --image=nginx nginx
kubectl -n nginx get pods
```

and

```sh
kubectl exec -it -n nginx nginx-6799fc88d8-n5tdd -- /bin/bash
```

#### (PG-ROOT) Container Run as Root User

Rule triggers, if container is started running as root

```sh
kubectl run -it busybox --image busybox -- /bin/sh
```

### Integrity Monitoring in Containers

#### (PG-IMC) Detect New File

#### (PG-IMC) Detect New Directory

#### (PG-IMC) Detect File Permission or Ownership Change

#### (PG-IMC) Detect Directory Change

### Integrity Monitoring on Host and Containers

#### (PG-IM) Kernel Module Modification
#### (PG-IM) Node Created in Filesystem

#### (PG-IM) Listen on New Port

### Admin Activities

#### (PG-ADM) Detect su or sudo

```sh
sudo su -
```

#### (PG-ADM) Package Management Launched

```sh
sudo apt update
```

### SSH

#### (PG-SSH) Inbound SSH Connection

#### (PG-SSH) Outbound SSH Connection

### Miscellaneous

#### (PG-KUBECTL) K8s Vulnerable Kubectl Copy

