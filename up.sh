#!/bin/sh
set -o errexit

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
REGISTRY_NAME="$(jq -r '.host_registry_name' config.json)"
REGISTRY_PORT="$(jq -r '.host_registry_port' config.json)"

# create registry container unless it already exists
printf '%s' "host registry"

running="$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "${REGISTRY_PORT}:${REGISTRY_PORT}" --name "${REGISTRY_NAME}" \
    registry:2 > /dev/null 2>&1
fi
printf ' %s\n' "created"

# create a cluster with the local registry enabled in containerd
printf '%s' "cluster"

cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  # - containerPort: 443
  #   hostPort: 443
  #   listenAddress: "0.0.0.0"
  #   protocol: tcp
  # - containerPort: 443
  #   hostPort: 1443
  #   listenAddress: "0.0.0.0"
  #   protocol: tcp
  # - containerPort: 80
  #   hostPort: 80
  #   protocol: TCP
  # - containerPort: 80
  #   hostPort: 8080
  #   listenAddress: "0.0.0.0"
  #   protocol: tcp
  - containerPort: 5000
    hostPort: 5000
    listenAddress: "0.0.0.0"
    protocol: tcp
# - role: worker
# - role: worker
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
          endpoint = ["http://${REGISTRY_NAME}:${REGISTRY_PORT}"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.1:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.2:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.18.255.3:5000".tls]
          insecure_skip_verify = true
EOF

printf ' %s\n' "created"

# connect the registry to the cluster network
# (the network may already be connected)
printf '%s\n' "configure host registry"

docker network connect "kind" "${REGISTRY_NAME}" || true

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# load balancer
printf '%s\n' "create load balancer"

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
ADDRESS_POOL=$(kubectl get nodes -o json | jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address' | sed -r 's|([0-9]*).([0-9]*).*|\1.\2.255.1-\1.\2.255.250|')

cat <<EOF | kubectl apply -f -
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

# ingress
printf '%s' "create ingress controller"

kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
