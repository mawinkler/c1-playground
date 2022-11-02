#!/bin/bash

set -e

if [[ $(aws sts get-caller-identity --query Arn 2> /dev/null | grep assumed-role) == "" ]]; then
  echo Ensure to turn of AWS managed temporary credentials
  # exit 0
else
  echo Cloud9 owns instance role, continuing...
fi

FAIL=0
if [ -v $AWS_ACCESS_KEY_ID ]; then
  echo Please set AWS_ACCESS_KEY_ID with: 'export AWS_ACCESS_KEY_ID=<YOUR ACCESS KEY>'
  FAIL=1
fi
if [ -v $AWS_SECRET_ACCESS_KEY ]; then
  echo Please set AWS_ACCESS_KAWS_SECRET_ACCESS_KEYEY_ID with: 'export AWS_SECRET_ACCESS_KEY=<YOUR ACCESS KEY>'
  FAIL=1
fi
if [ -v $AWS_ACCESS_KEY_ID ]; then
  echo Please set AWS_ACCESS_KEY_ID with: 'export AWS_ACCESS_KEY_ID=<YOUR ACCESS KEY>'
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
