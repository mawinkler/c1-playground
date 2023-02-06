# Add-On: Cilium

## Install the Cilium CLI

```sh
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}
```

## Install Cilium

```sh
cilium install
```

Validate the Installation

```sh
cilium status --wait
```

## Enable Hubble in Cilium

```sh
cilium hubble enable
```

Validate

```sh
cilium status
```

```sh
    /¯¯\
 /¯¯\__/¯¯\    Cilium:         OK
 \__/¯¯\__/    Operator:       OK
 /¯¯\__/¯¯\    Hubble:         OK
 \__/¯¯\__/    ClusterMesh:    disabled
    \__/

DaemonSet         cilium             Desired: 1, Ready: 1/1, Available: 1/1
Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
Deployment        hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
Containers:       hubble-relay       Running: 1
                  cilium             Running: 1
                  cilium-operator    Running: 1
Cluster Pods:     3/39 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.11.3@sha256:cb6aac121e348abd61a692c435a90a6e2ad3f25baa9915346be7b333de8a767f: 1
                  cilium-operator    quay.io/cilium/operator-generic:v1.11.3@sha256:5b81db7a32cb7e2d00bb3cf332277ec2b3be239d9e94a8d979915f4e6648c787: 1
                  hubble-relay       quay.io/cilium/hubble-relay:v1.11.3@sha256:7256ec111259a79b4f0e0f80ba4256ea23bd472e1fc3f0865975c2ed113ccb97: 1
```

Install the Hubble Client

```sh
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
rm hubble-linux-amd64.tar.gz{,.sha256sum}
```

Enable the Hubble UI

```sh
cilium hubble enable --ui
```

Open the Hubble UI

```sh
cilium hubble ui
```
