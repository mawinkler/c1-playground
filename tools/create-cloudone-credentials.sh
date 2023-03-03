#!/bin/bash

mkdir -p cloud-one

echo "$(yq '.services[] | select(.name=="cloudone") | .api_key' $PGPATH/config.yaml)" > cloud-one/api_key
echo "$(yq '.services[] | select(.name=="cloudone") | .region' $PGPATH/config.yaml).$(yq '.services[] | select(.name=="cloudone") | .instance' $PGPATH/config.yaml).trendmicro.com:443" > cloud-one/c1_url
