#!/bin/bash
set -o errexit

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
HOST_REGISTRY_NAME=playground-host-registry
HOST_REGISTRY_PORT="$(jq -r '.services[] | select(.name=="playground-host-registry") | .port' config.json)"
OS="$(uname)"
HOST_IP=$(hostname -I | awk '{print $1}')

printf '%s\n' "Target environment ${OS}"
echo > up.log
mkdir -p overrides

function create_cluster_linux {
  # create a cluster with the local registry enabled in containerd

  # Falco and Kubernetes Auditing
  # To enable Kubernetes audit logs, you need to change the arguments to the
  # kube-apiserver process to add --audit-policy-file and
  # --audit-webhook-config-file arguments and provide files that implement an
  # audit policy/webhook configuration.
  printf '%s\n' "Create K8s Audit Webhook (linux)"
  cat <<EOF >audit/audit-webhook.yaml
apiVersion: v1
kind: Config
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    # certificate-authority: /path/to/ca.crt # for https
    server: http://127.0.0.1:32765/k8s-audit
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ""
  name: default-context
current-context: default-context
preferences: {}
users: []
EOF

  printf '%s\n' "Create cluster (linux)"
  cat <<EOF | kind create cluster --config=-
#
# Cluster Configuration
#
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "${HOST_IP}"
  apiServerPort: 6443
  disableDefaultCNI: true # disable kindnet
  podSubnet: 192.168.0.0/16 # set to Calico's default subnet
name: ${CLUSTER_NAME}
nodes:
#
# Control Plane
#
- role: control-plane
  extraMounts:

  # Falco
  - hostPath: /dev
    containerPath: /dev
  - hostPath: /usr/src
    containerPath: /usr/src

  # Kube Audit
  - hostPath: $(pwd)/log/
    containerPath: /var/log/
  - hostPath: $(pwd)/audit/
    containerPath: /var/lib/k8s-audit/

  kubeadmConfigPatches:

  # Ingress
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"

# Workers
# - role: worker
# - role: worker

#
# Kube Audit
#
kubeadmConfigPatches:
- |
  kind: ClusterConfiguration
  apiServer:
    extraArgs:
      audit-log-path: "/var/log/k8s-audit.log"
      audit-log-maxage: "3"
      audit-log-maxbackup: "1"
      audit-log-maxsize: "10"
      audit-policy-file: "/var/lib/k8s-audit/audit-policy.yaml"
      # audit-webhook-batch-max-wait: "5s"
      audit-webhook-config-file: "/var/lib/k8s-audit/audit-webhook.yaml"
    extraVolumes:
    - name: audit
      hostPath: /var/log/
      mountPath: /var/log/
    - name: auditcfg
      hostPath: /var/lib/k8s-audit/
      mountPath: /var/lib/k8s-audit/

#
# Registries
#
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${HOST_REGISTRY_PORT}"]
          endpoint = ["http://${HOST_REGISTRY_NAME}:${HOST_REGISTRY_PORT}"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.1:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.2:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.3:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.19.255.1:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.19.255.2:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.19.255.3:5000".tls]
          insecure_skip_verify = true
EOF
}

function create_cluster_darwin {
  # create a cluster with the local registry enabled in containerd

  # Falco and Kubernetes Auditing
  # To enable Kubernetes audit logs, you need to change the arguments to the
  # kube-apiserver process to add --audit-policy-file and
  # --audit-webhook-config-file arguments and provide files that implement an
  # audit policy/webhook configuration.
  printf '%s\n' "Create K8s Audit Webhook (linux)"
  cat <<EOF >audit/audit-webhook.yaml
apiVersion: v1
kind: Config
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    # certificate-authority: /path/to/ca.crt # for https
    server: http://127.0.0.1:32765/k8s-audit
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ""
  name: default-context
current-context: default-context
preferences: {}
users: []
EOF

  printf '%s\n' "Create cluster (darwin)"
  cat <<EOF | kind create cluster --config=-
#
# Cluster Configuration
#
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true # disable kindnet
  podSubnet: 192.168.0.0/16 # set to Calico's default subnet
name: ${CLUSTER_NAME}
nodes:
#
# Control Plane
#
- role: control-plane
  extraMounts:

  # Falco
  - hostPath: /dev
    containerPath: /dev

  # Kube Audit
  - hostPath: $(pwd)/log/
    containerPath: /var/log/
  - hostPath: $(pwd)/audit/
    containerPath: /var/lib/k8s-audit/

  kubeadmConfigPatches:

  # Ingress
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  
  # Port Mappings
  extraPortMappings:
  - containerPort: 443
    hostPort: 443
    # listenAddress: "0.0.0.0"
    # listenAddress: "127.0.0.1"
    protocol: tcp
  - containerPort: 80
    hostPort: 80
    # listenAddress: "0.0.0.0"
    # listenAddress: "127.0.0.1"
    protocol: TCP


# Workers
# - role: worker
# - role: worker

#
# Kube Audit
#
kubeadmConfigPatches:
- |
  kind: ClusterConfiguration
  apiServer:
    extraArgs:
      # audit-log-max-backups: "1"
      # audit-log-max-size: "10"
      audit-log-path: "/var/log/k8s-audit.log"
      audit-policy-file: "/var/lib/k8s-audit/audit-policy.yaml"
      # audit-webhook-batch-max-wait: "5s"
      audit-webhook-config-file: "/var/lib/k8s-audit/audit-webhook.yaml"
    extraVolumes:
    - name: audit
      hostPath: /var/log/
      mountPath: /var/log/
    - name: auditcfg
      hostPath: /var/lib/k8s-audit/
      mountPath: /var/lib/k8s-audit/

#
# Registries
#
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${HOST_REGISTRY_PORT}"]
          endpoint = ["http://${HOST_REGISTRY_NAME}:${HOST_REGISTRY_PORT}"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.1:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.2:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.3:5000".tls]
          insecure_skip_verify = true
EOF
}

function create_host_registry {
  # Here, we're creating a registry, running on the docker host directly. It
  # will be accessibble from the host and the cluster. Since the current setup is
  # is not using this registry, it will not be deployed. An authenticated
  # registry running on the cluster is used instead.

  # create registry container unless it already exists
  printf '%s\n' "Create host registry"

  running="$(docker inspect -f '{{.State.Running}}' "${HOST_REGISTRY_NAME}" 2>/dev/null || true)"
  if [ "${running}" != 'true' ]; then
    docker run \
      -d --restart=always -p "${HOST_REGISTRY_PORT}:5000" --name "${HOST_REGISTRY_NAME}" \
      registry:2 >/dev/null 2>&1
  fi
  printf '%s\n' "Host registry created 🍺"
}

function configure_host_registry {
  # connect the registry to the cluster network
  # (the network may already be connected)
  printf '%s\n' "Configure host registry"

  docker network connect "kind" "${HOST_REGISTRY_NAME}" || true

  # Document the local registry
  # https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/ \
  # generic/1755-communicating-a-local-registry
  echo "---" >> up.log
  cat <<EOF | kubectl apply -f - -o yaml | cat >> up.log
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${HOST_REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
  printf '%s\n' "Host registry configured 🍷"
}

function create_load_balancer {
  # load balancer
  printf '%s\n' "Create load balancer"

  echo "---" >> up.log && \
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml \
    -o yaml | cat >> up.log
  echo "---" >> up.log && \
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml \
    -o yaml | cat >> up.log
  echo "---" >> up.log && \
    kubectl create secret generic -n metallb-system memberlist \
    --from-literal=secretkey="$(openssl rand -base64 128)" \
    -o yaml | cat >> up.log
  ADDRESS_POOL=$(kubectl get nodes -o json | \
    jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address' | \
    sed -r 's|([0-9]*).([0-9]*).*|\1.\2.255.1-\1.\2.255.250|')

  echo "---" >> up.log
  cat <<EOF | kubectl apply -f - -o yaml | cat >> up.log 
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${ADDRESS_POOL}
EOF
  printf '%s\n' "Load balancer created 🍹"
}

function create_ingress_controller {
  # ingress nginx
  printf '%s\n' "Create ingress controller"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml -o yaml | cat >> up.log

  # wating for the cluster be ready
  printf '%s' "Wating for the cluster be ready"

  while [ $(kubectl -n kube-system get deployments | \
          grep -cE "1/1|2/2|3/3|4/4|5/5") -ne $(kubectl -n kube-system get deployments | \
          grep -c "/") ]; do
    printf '%s' "."
    sleep 2
  done

  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s \
    -o yaml | cat >> up.log
    
  printf '\n%s\n' "Cluster and ingress controller ready 🍾"
}

function deploy_cadvisor {
  # cadvisor
  kubectl apply -f https://raw.githubusercontent.com/astefanutti/kubebox/master/cadvisor.yaml
}

function deploy_calico {
  # Deploy calico
  kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml

  # By default, Calico pods fail if the Kernel's Reverse Path Filtering (RPF) check
  # is not enforced. This is a security measure to prevent endpoints from spoofing
  # their IP address.
  # The RPF check is not enforced in Kind nodes. Thus, we need to disable the
  # Calico check by setting an environment variable in the calico-node DaemonSet
  kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
}

# flush logfile
echo > up.log
# flush services
echo > services

if [ "${OS}" == 'Linux' ]; then
  # create_host_registry
  create_cluster_linux
  deploy_cadvisor
  deploy_calico
  # configure_host_registry
  create_load_balancer
  create_ingress_controller
fi

if [ "${OS}" == 'Darwin' ]; then
  # create_host_registry
  create_cluster_darwin
  deploy_cadvisor
  deploy_calico
  # configure_host_registry
  create_load_balancer
  create_ingress_controller
fi
