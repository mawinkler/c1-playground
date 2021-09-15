# Play with Falco & Container Security

- [Play with Falco & Container Security](#play-with-falco--container-security)
  - [Plays for Falco](#plays-for-falco)
    - [Trigger: (Playground) Attach/Exec Pod with Terminal User shell in container](#trigger-playground-attachexec-pod-with-terminal-user-shell-in-container)
    - [Trigger: (Playground) Attach/Exec Pod with Terminal Root shell in container](#trigger-playground-attachexec-pod-with-terminal-root-shell-in-container)
    - [Trigger: (Playground) Container Run as Root User](#trigger-playground-container-run-as-root-user)
    - [Trigger: (Playground) Information gathering detected](#trigger-playground-information-gathering-detected)
    - [Trigger: (Playground) Unexpected Spawned Process in kshell](#trigger-playground-unexpected-spawned-process-in-kshell)
    - [Trigger: (Playground) Kubernetes Outbound Connection](#trigger-playground-kubernetes-outbound-connection)

## Plays for Falco

These examples are based on the default Falco ruleset and the additional rules provided by the playground.

### Trigger: (Playground) Attach/Exec Pod with Terminal User shell in container

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

### Trigger: (Playground) Attach/Exec Pod with Terminal Root shell in container

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

### Trigger: (Playground) Container Run as Root User

Rule triggers, if container is started running as root

```sh
kubectl run -it busybox --image busybox -- /bin/sh
```

### Trigger: (Playground) Information gathering detected

Triggers, if one of the named tools (whoami, nmap, racoon) is run inside a container.

```sh
kubectl run -it busybox --image busybox -- /bin/sh
/ # whoami
```

### Trigger: (Playground) Unexpected Spawned Process in kshell

Triggers, if any process not in the list `kshell_allowed_processes` is run.

```sh
kubectl run -it --image=ubuntu kshell --restart=Never --rm -- /bin/bash
root@kshell:/# tail /var/log/bootstrap.log 
```

### Trigger: (Playground) Kubernetes Outbound Connection

Triggers, if a container is initiating an outbound network communication via TCP or UDP.

```sh
kubectl exec -it -n nginx nginx-6799fc88d8-n5tdd -- /bin/bash
root@nginx-6799fc88d8-n5tdd:/# curl www.google.com
```
