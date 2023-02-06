#!/bin/bash
CLUSTER=$(kubectl config current-context)

rm migrate/source/*

for ns in $(kubectl get ns --no-headers | cut -d " " -f1); do
  if { [ "$ns" != "kube-system" ] && \
       [ "$ns" != "registry" ] && \
       [ "$ns" != "default" ]; }; then
    printf '%s\n' "Processing namespace ${ns}"
    rm -f migrate/source/${ns}.json

    kubectl --namespace="${ns}" get -o=json \
      replicationcontrollers,replicasets,deployments,configmaps,secrets,daemonsets,statefulsets,ingress | \
        jq '. |
            del(.items[] | select(.type == "kubernetes.io/service-account-token")) |
            del(
                .items[].spec.clusterIP,
                .items[].metadata.uid,
                .items[].metadata.selfLink,
                .items[].metadata.resourceVersion,
                .items[].metadata.creationTimestamp,
                .items[].metadata.generation,
                .items[].status,
                .items[].spec.template.spec.securityContext,
                .items[].spec.template.spec.dnsPolicy,
                .items[].spec.template.spec.terminationGracePeriodSeconds,
                .items[].spec.template.spec.restartPolicy
            )' >> migrate/source/${ns}.json
  fi
done
