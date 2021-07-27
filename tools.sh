#!/bin/bash
set -o errexit

# install packages
sudo apt update && \
  sudo apt install -y jq apt-transport-https gnupg2 curl nginx

if ! command -v docker &>/dev/null; then
  printf '%s\n' "installing docker"
  # install docker
  curl -fsSL https://get.docker.com -o get-docker.sh && \
    sudo sh get-docker.sh && \
    ME=$(whoami) && \
    sudo usermod -aG docker ${ME}
else
  printf '%s\n' "docker already installed"
fi

if ! command -v kubectl &>/dev/null; then
  printf '%s\n' "installing kubectl"
  # kubectl
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list && \
    sudo apt-get update && \
    sudo apt-get install -y kubectl
else
  printf '%s\n' "kubectl already installed"
fi

if ! command -v kustomize &>/dev/null; then
  printf '%s\n' "installing kustomize"
  # kustomize
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && \
    sudo mv ~/kustomize /usr/local/bin
else
  printf '%s\n' "kustomize already installed"
fi

if ! command -v helm &>/dev/null; then
  printf '%s\n' "installing helm"
  # helm
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh
else
  printf '%s\n' "helm already installed"
fi

if ! command -v kind &>/dev/null; then
  printf '%s\n' "installing kind"
  # kind
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64 && \
    chmod +x ./kind && \
    sudo mv kind /usr/local/bin/
else
  printf '%s\n' "kind already installed"
fi

if ! command -v ~/.krew/bin/kubectl-krew &>/dev/null; then
  printf '%s\n' "installing krew"
  # krew
  curl -fsSL "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" -o ./krew.tar.gz && \
    tar zxvf ./krew.tar.gz && \
    KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm/')" && \
    "$KREW" install krew && \
    rm -f ./krew.tar.gz ./krew-* && \
    echo 'export PATH=~/.krew/bin:$PATH' >> ~/.bashrc
else
  printf '%s\n' "krew already installed"
fi

if ! command -v kubebox &>/dev/null; then
  printf '%s\n' "installing kubebox"
  # kubebox
  curl -Lo kubebox https://github.com/astefanutti/kubebox/releases/download/v0.9.0/kubebox-linux && \
    chmod +x kubebox && \
    sudo mv kubebox /usr/local/bin/kubebox
else
  printf '%s\n' "kubebox already installed"
fi
