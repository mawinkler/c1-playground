#!/bin/bash

# Gets all images used within current namespace and creates as argument list
# for scan-image.sh with "imagename tag"
kubectl get pods -o jsonpath="{..image}" | \
  tr -s "[[:space:]]" "\n" | \
  sort -u | \
  xargs -L 1 -t /bin/bash ./scan-image.sh