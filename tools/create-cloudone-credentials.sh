#!/bin/bash

mkdir -p cloud-one

echo "$(jq -r '.services[] | select(.name=="cloudone") | .api_key' config.json)" > cloud-one/api_key
echo "$(jq -r '.services[] | select(.name=="cloudone") | .region' config.json).cloudone.trendmicro.com:443" > cloud-one/c1_url
