#!/bin/bash

mkdir -p cloud-one

echo "$(jq -r '.services[] | select(.name=="cloudone") | .api_key' $PGPATH/config.json)" > cloud-one/api_key
echo "$(jq -r '.services[] | select(.name=="cloudone") | .region' $PGPATH/config.json).$(jq -r '.services[] | select(.name=="cloudone") | .instance' $PGPATH/config.json).trendmicro.com:443" > cloud-one/c1_url
