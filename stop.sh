#!/bin/bash

REG_NAME='playground-registry'

kind delete cluster
docker stop ${REG_NAME}
docker rm ${REG_NAME}
