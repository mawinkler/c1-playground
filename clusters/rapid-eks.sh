#!/bin/bash

#######################################
# Main:
# Deploys EKS Cluster
#######################################
function main() {
  # Exports
  export AWS_REGION=$(aws configure get region)
  export KEY_NAME=playground-$(openssl rand -hex 4)
  rm -f ~/.ssh/id_rsa_pg  ~/.ssh/id_rsa_pg.pub
  ssh-keygen -q -f ~/.ssh/id_rsa_pg -P ""
  aws ec2 import-key-pair --key-name ${KEY_NAME} --public-key-material fileb://~/.ssh/id_rsa_pg.pub
  export KEY_ALIAS_NAME=alias/${KEY_NAME}
  aws kms create-alias --alias-name ${KEY_ALIAS_NAME} --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
  export MASTER_ARN=$(aws kms describe-key --key-id ${KEY_ALIAS_NAME} --query KeyMetadata.Arn --output text)
  echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bashrc
  export CLUSTER_NAME=$(jq -r '.cluster_name' config.json)-$(openssl rand -hex 4)

  cat << EOF | eksctl create cluster -f -
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}

managedNodeGroups:
- name: nodegroup
  desiredCapacity: 2
  iam:
    withAddonPolicies:
      albIngress: true
      ebs: true
      cloudWatch: true
      autoScaler: true
      awsLoadBalancerController: true

secretsEncryption:
  keyARN: ${MASTER_ARN}
EOF

  # Deploy Amazon AWS Calico
  kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/calico-operator.yaml
  kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/calico-crs.yaml

  # Deploy Amazon EBS CSI driver
  # Link: https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md
  kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.12"

  #aws eks update-kubeconfig --region ${CLUSTER_NAME} --name ${AWS_REGION}

  echo "Creating rapid-eks-down.sh script"
  cat <<EOF >rapid-eks-down.sh
set -e

AWS_REGION=${AWS_REGION}
CLUSTER_NAME=${CLUSTER_NAME}
KEY_NAME=${KEY_NAME}
KEY_ALIAS_NAME=${KEY_ALIAS_NAME}

EXISTING_NAMESPACES=\$(kubectl get ns -o json | jq -r '.items[].metadata.name' | tr '\n' '|')

for NAMESPACE in \$(cat config.json | jq -r '.services[].namespace' | sort | uniq); do
  if [ "\$NAMESPACE" != "null" ] && [[ ! "\$NAMESPACE" =~ "kube-system"|"kube-public"|"kube-node-lease"|"default" ]]; then
    if [[ \$EXISTING_NAMESPACES == *"\$NAMESPACE"* ]]; then
      kubectl delete namespace \${NAMESPACE}
    fi
  fi
done
eksctl delete cluster --name \${CLUSTER_NAME}
# Delete Keys
aws ec2 delete-key-pair --key-name \${KEY_NAME}
aws kms delete-alias --alias-name \${KEY_ALIAS_NAME}
sudo rm -Rf auth certs audit/audit-webhook.yaml /tmp/passthrough.conf log/* services opa
EOF
  chmod +x rapid-eks-down.sh
  echo "Run rapid-eks-down.sh to tear down everything"
}

function cleanup() {
  ./rapid-eks-down.sh
  if [ $? -eq 0 ] ; then
    return
  fi
  false
}

function test() {
  for i in {1..60} ; do
    sleep 5
    DEPLOYMENTS_TOTAL=$(kubectl get deployments -A | wc -l)
    DEPLOYMENTS_READY=$(kubectl get deployments -A | grep -E "([0-9]+)/\1" | wc -l)
    if [ $((${DEPLOYMENTS_TOTAL} - 1)) -eq ${DEPLOYMENTS_READY} ] ; then
      echo ${DEPLOYMENTS_READY}
      return
    fi
  done
  false
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi