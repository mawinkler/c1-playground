#!/bin/bash

set -e

NAMESPACE="$(jq -r '.services[] | select(.name=="falco") | .namespace' config.json)"
OS="$(uname)"

function create_namespace {
  printf '%s' "Create falco namespace"

  echo "---" >>up.log
  # create service
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspace {
  printf '%s\n' "Whitelist namespace"

  # whitelist namespace for falco
  kubectl label namespace ${NAMESPACE} --overwrite ignoreAdmissionControl=ignore
  kubectl label namespace ${NAMESPACE} --overwrite network=green
}

function deploy_falco {
  ## deploy falco
  printf '%s\n' "deploy falco"

  helm repo add falcosecurity https://falcosecurity.github.io/charts
  helm repo update

  cat <<EOF > overrides/overrides-falco.yaml
auditLog:
  enabled: true
falco:
  jsonOutput: true
  jsonIncludeOutputProperty: true
  grpc:
    enabled: true
  grpcOutput:
    enabled: true
falcosidekick:
  enabled: true
  webui:
    enabled: true
    service:
      type: LoadBalancer
EOF

  cat <<EOF > overrides/custom-rules.yaml
customRules:
  rules-networking.yaml: |-
    # Creates a macro outbound_corp that deals with any outbound connection
    # Creates a list k8s_not_monitored with values blue and green
    # Creates a rule that verifies:
    # - If it’s an outbound traffic defined in macro outbound_corp
    # - AND If the field k8s.ns.name is defined (which means it’s being executed
    #   inside Kubernetes)
    # - AND if the namespace containing the Pod does not have a label network
    #   containing any of the values in list k8s_not_monitored. If it does, the
    #   traffic wont be monitored
    # Whitelist a namespace by:
    # kubectl label ns falco --overwrite network=green (or blue)
    - macro: outbound_corp
      condition: >
        (((evt.type = connect and evt.dir=<) or
          (evt.type in (sendto,sendmsg) and evt.dir=< and
           fd.l4proto != tcp and fd.connected=false and fd.name_changed=true)) and
         (fd.typechar = 4 or fd.typechar = 6) and
         (fd.ip != "0.0.0.0" and fd.net != "127.0.0.0/8") and
         (evt.rawres >= 0 or evt.res = EINPROGRESS))

    - list: k8s_not_monitored
      items: ['"green"', '"blue"']

    - rule: Kubernetes Outbound Connection
      desc: A pod in namespace attempted to connect to the outer world
      condition: outbound_corp and k8s.ns.name != "" and not k8s.ns.label.network in (k8s_not_monitored)
      output: "Outbound network traffic connection from a Pod: (pod=%k8s.pod.name namespace=%k8s.ns.name srcip=%fd.cip dstip=%fd.sip dstport=%fd.sport proto=%fd.l4proto procname=%proc.name)"
      priority: WARNING
    
    # Here, I'm modifying the health_endpoints which is used for the "Anonymous Request Allowed"
    # rule, required for CIS Benchmark 1.1.1.
    # By default, Falco sets the endpoint to 'healthz' only which causes to many events for
    # this playground
    - macro: health_endpoint
      condition: ka.uri=/healthz or ka.uri=/readyz or ka.uri=/livez

    # We create an event, if someone runs whoami within a container
    - rule: The Program "whoami" is run in a Container
      desc: An event will trigger every time you run "whoami" in a container
      condition: evt.type = execve and evt.dir=< and container.id != host and proc.name = whoami
      output: "Whoami command run in container (user=%user.name %container.info parent=%proc.pname cmdline=%proc.cmdline)"
      priority: WARNING

    # We create an event, if someone runs locate within a container
    - rule: The Program "locate" is run in a Container
      desc: An event will trigger every time you run "locate" in a container
      condition: evt.type = execve and evt.dir=< and container.id != host and proc.name = locate
      output: "Locate command run in container (user=%user.name %container.info parent=%proc.pname cmdline=%proc.cmdline)"
      priority: WARNING

    # kshell
    # To easily run kshell, you can set an alias to
    # alias kshell='kubectl run -it --image=ubuntu kshell --restart=Never --rm -- /bin/bash'
    # kshell will spawn an ubuntu based bash in the current namespace
    - macro: app_kshell
      condition: k8s.pod.name contains "kshell" and container.image contains "ubuntu"

    - list: kshell_allowed_processes
      items: [ curl, apt, grep, sort, sed, dpkg, dpkg-deb, tar ]

    - rule: Unexpected Spawned Process kshell
      desc: Detect a process started in a kshell container outside of an expected set
      condition: spawned_process and not proc.name in (kshell_allowed_processes) and app_kshell
      output: Unexpected process spawned in kshell container (command=%proc.cmdline pid=%proc.pid user=%user.name %container.info image=%container.image)
      priority: NOTICE
EOF

  # helm delete falco && kubectl delete svc falco-np && rm /tmp/passthrough.conf && sleep 2 && ./deploy-falco.sh 

  # Install Falco
  helm -n ${NAMESPACE} upgrade \
    falco \
    --install \
    --values=overrides/overrides-falco.yaml \
    -f overrides/custom-rules.yaml \
    falcosecurity/falco

  helm -n ${NAMESPACE} upgrade \
    falco-exporter \
    --install \
    falcosecurity/falco-exporter

  # Create NodePort Service to enable K8s Audit
  cat <<EOF | kubectl -n ${NAMESPACE} apply -f -
kind: Service
apiVersion: v1
metadata:
  name: falco-np
spec:
  selector:
    app: falco
  ports:
  - protocol: TCP
    port: 8765
    nodePort: 32765
  type: NodePort
EOF
}

create_namespace
whitelist_namsspace
deploy_falco

if [ "${OS}" == 'Linux' ]; then
  ./deploy-proxy.sh falco
fi