#!/bin/bash

# Exports
export AWS_REGION=eu-central-1
export KEY_NAME=playground-$(openssl rand -hex 4)
aws ec2 import-key-pair --key-name ${KEY_NAME} --public-key-material fileb://~/.ssh/id_rsa.pub
export KEY_ALIAS_NAME=alias/${KEY_NAME}
aws kms create-alias --alias-name ${KEY_ALIAS_NAME} --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
export MASTER_ARN=$(aws kms describe-key --key-id ${KEY_ALIAS_NAME} --query KeyMetadata.Arn --output text)
echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bashrc
export CLUSTER_NAME=playground-$(openssl rand -hex 4)

cat << EOF | eksctl create cluster -f -
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}

managedNodeGroups:
- name: nodegroup
  desiredCapacity: 3
  iam:
    withAddonPolicies:
      albIngress: true

secretsEncryption:
  keyARN: ${MASTER_ARN}
EOF

echo "Done."

echo "Delete project run: clusters/rapid-eks-down.sh"
