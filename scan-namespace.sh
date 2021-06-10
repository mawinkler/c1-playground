#!/bin/bash

# Gets all images used within current namespace and creates as argument list
# for scan-image.sh with "imagename tag"
kubectl get pods -o jsonpath="{..image}" | \
  tr -s "[[:space:]]" "\n" | \
  sort -u | \
  tr -s ":" " " | \
  xargs -L 1 ./scan-image.sh