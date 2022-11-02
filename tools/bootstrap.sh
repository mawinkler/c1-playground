#!/bin/bash

set -e

FAIL=0
if [[ $(aws sts get-caller-identity --query Arn 2> /dev/null | grep assumed-role) =~ "ekscluster" ]]; then
  echo Instance role set
elif [ "$(aws sts get-caller-identity --query Arn 2> /dev/null)" == "" ]; then
  echo AWS managed temporary credentials off 
else
  echo Turn off AWS managed temporary credentials
  FAIL=1
fi
if [ -v $AWS_ACCESS_KEY_ID ]; then
  echo Please set AWS_ACCESS_KEY_ID with: 'export AWS_ACCESS_KEY_ID=<YOUR ACCESS KEY>'
  FAIL=1
fi
if [ -v $AWS_SECRET_ACCESS_KEY ]; then
  echo Please set AWS_SECRET_ACCESS_KEY with: 'export AWS_SECRET_ACCESS_KEY=<YOUR ACCESS KEY>'
  FAIL=1
fi
if [ -v $AWS_DEFAULT_REGION ]; then
  echo Please set AWS_DEFAULT_REGION with: 'export AWS_DEFAULT_REGION=<YOUR DESIRED REGION>'
  FAIL=1
fi
if [ "$FAIL" == "1" ]; then
  exit 0
fi

REPO=https://raw.githubusercontent.com/mawinkler/c1-playground/master

sudo apt install -y jq apt-transport-https gnupg2 curl nginx apache2-utils pv

curl -L ${REPO}/tools/aws2-install.sh | bash
curl -L ${REPO}/tools/cloud9-instance-role.sh | bash

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

aws sts get-caller-identity --query Arn | \
  grep ekscluster-admin -q && \
  echo "IAM role valid" || echo "IAM role NOT valid"

curl -L ${REPO}/tools/cloud9-resize.sh | bash

#/bin/bash -c $(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
NONINTERACTIVE=1 curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash

echo '# Set PATH, MANPATH, etc., for Homebrew.' >> /home/ubuntu/.bash_profile
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/ubuntu/.bash_profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew install kubernetes-cli
brew install eksctl
brew install kustomize
brew install helm
brew install kind
brew install stern
brew install krew
