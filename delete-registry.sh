#!/bin/bash

set -e

REG_NAME=registry2

kubectl delete secret certs-secret --ignore-not-found
kubectl delete secret auth-secret --ignore-not-found

kubectl delete deployment ${REG_NAME} --ignore-not-found
kubectl delete svc ${REG_NAME} --ignore-not-found
kubectl delete pvc docker-repo-pvc --ignore-not-found

rm -Rf auth certs
