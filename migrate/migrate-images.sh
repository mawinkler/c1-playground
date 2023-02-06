#!/bin/bash

CLUSTER_JSON=$(kubectl config current-context)
CLUSTER_MIGRATED_JSON=$(kubectl config current-context)-migrated

. $PGPATH/bin/playground-helpers.sh
. $PGPATH/bin/scan-image -so

get_registry

rm migrate/migrated/*

for ns in migrate/source/*.json ; do
    IMAGES=$(cat ${ns} | \
        jq -r '.. | objects | select(.image?) | .image' | \
        sort | \
        uniq)

    # migrate namespace
    # basename
    bs=${ns##*/}
    # add registry prefix and strip an eventual digest
    cat ${ns} | \
        jq --arg registry "$REGISTRY" '
          walk(
            if type=="object" and .image then 
              if (.image | contains("@")) then
                .image=$registry+"/"+(.image | capture("(?<image>.*)@").image) 
              else
                .image=$registry+"/"+.image
              end
            else . end
          )' | \
        kubectl create -o yaml --dry-run=true -f - > migrate/migrated/${bs%.*}.yaml

    # Initiate a scan with pull and push to cluster registry
    for image in ${IMAGES} ; do
        printf '%s\n' "Processing image ${image}"
        scan-image ${image} || true
    done

    cat <<EOF >migrate/kustomization.yaml
resources:
  - migrated/${bs%.*}.yaml

commonLabels:
  migrated: playground

patches:
- path: regcred-daemonset.yaml
  target:
    kind: DaemonSet
- path: regcred-replicaset.yaml
  target:
    kind: ReplicaSet
- path: regcred-statefulset.yaml
  target:
    kind: StatefulSet
- path: regcred-deployment.yaml
  target:
    kind: Deployment
EOF

    kubectl delete -f ${ns}
    kubectl create secret docker-registry regcred \
        --docker-server=${REGISTRY} \
        --docker-username=admin \
        --docker-password=trendmicro \
        --namespace=${bs%.*}
    kubectl create -k migrate/.
done
