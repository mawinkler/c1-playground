#!/bin/bash

CLUSTER=$(kubectl config current-context)

rm migrate/source/*

for ns in $(kubectl get ns --no-headers | cut -d " " -f1); do
      #  [ "$ns" != "container-security" ] && \
      #  [ "$ns" != "smartcheck" ] && \
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



      # jq '.items[] |
      #     select(.type!="kubernetes.io/service-account-token") |
      #     del(
      #         .spec.clusterIP,
      #         .metadata.uid,
      #         .metadata.selfLink,
      #         .metadata.resourceVersion,
      #         .metadata.creationTimestamp,
      #         .metadata.generation,
      #         .status,
      #         .spec.template.spec.securityContext,
      #         .spec.template.spec.dnsPolicy,
      #         .spec.template.spec.terminationGracePeriodSeconds,
      #         .spec.template.spec.restartPolicy


      # jq '.items[] |
      #     select(.type!="kubernetes.io/service-account-token") |
      #     delpaths(
      #         [[".spec.clusterIP"],
      #         [".metadata.uid"],
      #         [".metadata.selfLink"],
      #         [".metadata.resourceVersion"],
      #         [".metadata.creationTimestamp"],
      #         [".metadata.generation"],
      #         [".status"],
      #         [".spec.template.spec.securityContext"],
      #         [".spec.template.spec.dnsPolicy"],
      #         [".spec.template.spec.terminationGracePeriodSeconds"],
      #         [".spec.template.spec.restartPolicy"]]

      # jq '. |
      #     select(.items[].type!="kubernetes.io/service-account-token") |
      #     del(
      #         .items[].spec.clusterIP,
      #         .items[].metadata.uid,
      #         .items[].metadata.selfLink,
      #         .items[].metadata.resourceVersion,
      #         .items[].metadata.creationTimestamp,
      #         .items[].metadata.generation,
      #         .items[].status,
      #         .items[].spec.template.spec.securityContext,
      #         .items[].spec.template.spec.dnsPolicy,
      #         .items[].spec.template.spec.terminationGracePeriodSeconds,
      #         .items[].spec.template.spec.restartPolicy