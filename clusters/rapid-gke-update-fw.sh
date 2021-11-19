#!/bin/bash

# Set your DNS name here:
EXTERNAL_IP=$(dig marwinsworld.online +short)
echo External IP: ${EXTERNAL_IP}

RULES=$(gcloud compute firewall-rules list --format=json | jq -r '.[] | select(.name | startswith("k8s-fw-")) | .name')
echo Updating FW Rules: ${RULES}

for rule in ${RULES} ; do
  gcloud compute firewall-rules update $rule --source-ranges=${EXTERNAL_IP}
  echo New source range: $(gcloud compute firewall-rules describe $rule --format=json | jq -r '. | select(.name | startswith("k8s-fw-")) | .sourceRanges[0]')
done

