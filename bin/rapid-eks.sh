#!/bin/bash

#######################################
# Main:
# Deploys EKS Cluster
#######################################
function main() {
  # Exports
  export AWS_REGION=$(aws configure get region)
  export KEY_NAME=playground-$(openssl rand -hex 4)
  export CLUSTER_NAME=$(yq '.cluster_name' $PGPATH/config.yaml | tr '[:upper:]' '[:lower:]')-a-$(openssl rand -hex 4)

  #
  # Create instance access key pair
  #
  rm -f ~/.ssh/id_rsa_pg  ~/.ssh/id_rsa_pg.pub
  ssh-keygen -q -f ~/.ssh/id_rsa_pg -P ""
  aws ec2 import-key-pair --key-name ${KEY_NAME} --public-key-material fileb://~/.ssh/id_rsa_pg.pub
  export KEY_ALIAS_NAME=alias/${KEY_NAME}
  aws kms create-alias --alias-name ${KEY_ALIAS_NAME} --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
  export MASTER_ARN=$(aws kms describe-key --key-id ${KEY_ALIAS_NAME} --query KeyMetadata.Arn --output text)
  echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bashrc

  #
  # Get node instance type
  #
  T=$(yq '.cluster_instance_type' $PGPATH/config.yaml)
  [ ${T} == "null" ] && export INSTANCE_TYPE='t3.medium' || export INSTANCE_TYPE=${T}

  #
  # Create cluster
  #
  cat << EOF | eksctl create cluster -f -
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}

managedNodeGroups:
- name: nodegroup
  instanceType: ${INSTANCE_TYPE}
  minSize: 2
  maxSize: 4
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

  #
  # Deploy Amazon AWS Calico
  #
  helm repo add projectcalico https://docs.tigera.io/calico/charts
  helm repo update
  mkdir -p $PGPATH/overrides
  echo '{ installation: {kubernetesProvider: EKS }}' > $PGPATH/overrides/tigera-operator-overrides.yaml
  helm upgrade \
    calico \
    --version v3.25.0 \
    --namespace tigera-operator \
    --create-namespace \
    --install \
    -f $PGPATH/overrides/tigera-operator-overrides.yaml \
    projectcalico/tigera-operator

  #
  # Deploy Amazon EBS CSI driver
  #
  # Link: https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md
  kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.12"

  #aws eks update-kubeconfig --region ${CLUSTER_NAME} --name ${AWS_REGION}

  #
  # Enable CloudWatch logging
  #
  eksctl utils update-cluster-logging --enable-types=all --region=${AWS_REGION} --cluster=${CLUSTER_NAME} --approve

  #
  # Installing the AWS Load Balancer Controller add-on
  #
  # Create an IAM OIDC identity provider
  eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve

  # Test for AWSLoadBalancerControllerIAMPolicy, if not exist create it
  POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text)

  if [ "${POLICY_ARN}" == "" ]; then
    curl https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json -o overrides/iam_policy.json
    aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://$PGPATH/overrides/iam_policy.json

    POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text)
  fi

  # Create IAM role
  eksctl create iamserviceaccount \
    --cluster=${CLUSTER_NAME} \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --attach-policy-arn=${POLICY_ARN} \
    --approve

  # Install AWS Load Balancer Controller
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update eks
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=${CLUSTER_NAME} \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller 

  echo "Creating rapid-eks-down.sh script"
  cat <<EOF >$PGPATH/bin/rapid-eks-down.sh
set -e

AWS_REGION=${AWS_REGION}
CLUSTER_NAME=${CLUSTER_NAME}
KEY_NAME=${KEY_NAME}
KEY_ALIAS_NAME=${KEY_ALIAS_NAME}

EXISTING_NAMESPACES=\$(kubectl get ns -o json | jq -r '.items[].metadata.name' | tr '\n' '|')

for NAMESPACE in \$(yq '.services[].namespace' $PGPATH/config.yaml | sort | uniq); do
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
sudo rm -Rf $PGPATH/auth $PGPATH/certs $PGPATH/audit/audit-webhook.yaml /tmp/passthrough.conf $PGPATH/services $PGPATH/opa

printf '\n%s\n' "###TASK-COMPLETED###"
EOF
  chmod +x $PGPATH/bin/rapid-eks-down.sh
  echo "Run rapid-eks-down.sh to tear down everything"
}

function cleanup() {
  $PGPATH/bin/rapid-eks-down.sh
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

printf '\n%s\n' "###TASK-COMPLETED###"
