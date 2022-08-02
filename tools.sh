#!/bin/bash
set -o errexit

# Colors
# Num  Colour    #define         R G B
# 0    black     COLOR_BLACK     0,0,0
# 1    red       COLOR_RED       1,0,0
# 2    green     COLOR_GREEN     0,1,0
# 3    yellow    COLOR_YELLOW    1,1,0
# 4    blue      COLOR_BLUE      0,0,1
# 5    magenta   COLOR_MAGENTA   1,0,1
# 6    cyan      COLOR_CYAN      0,1,1
# 7    white     COLOR_WHITE     1,1,1
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
BOLD=$(tput bold)
RESET=$(tput sgr0)

OS="$(uname)"

# essential packages
# AMAZON LINUX
# sudo yum install -y jq apt-transport-https gnupg2 curl nginx
if [ "${OS}" == 'Linux' ]; then
  printf "${BLUE}${BOLD}%s${RESET}\n" "Installing essential packages on linux"
  sudo apt update && \
    sudo apt install -y jq apt-transport-https gnupg2 curl nginx apache2-utils pv
fi

# brew
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for brew"
if [ "${OS}" == 'Darwin' ]; then
  if ! command -v brew &>/dev/null; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing brew on darwin"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    printf "${YELLOW}%s${RESET}\n" "Brew already installed, updating packages"
    brew update
  fi
fi

# docker
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for docker"
if ! command -v docker &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing docker on linux"
    curl -fsSL https://get.docker.com -o get-docker.sh && \
      sudo sh get-docker.sh && \
      ME=$(whoami) && \
      sudo usermod -aG docker ${ME}
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing docker on darwin"
    brew cask install docker
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Docker already installed, ensuring latest version"
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Upgrading docker on linux"
    sudo apt upgrade -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Upgrading docker on darwin"
    brew cask upgrade docker
  fi
fi

# kubectl
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for kubectl"
if ! command -v kubectl &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing kubectl on linux"
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
      echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list && \
      sudo apt-get update && \
      sudo apt-get install -y kubectl
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing kubectl on darwin"
    brew install kubernetes-cli
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Kubectl already installed, ensuring latest version"
  if [ "${OS}" == 'Linux' ]; then
    sudo apt-get upgrade -y kubectl
  fi
  if [ "${OS}" == 'Darwin' ]; then
    brew upgrade kubernetes-cli
  fi
fi

# eksctl
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for eksctl"
if ! command -v eksctl &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing eksctl on linux"
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing eksctl on darwin"
    brew tap weaveworks/tap
    brew install weaveworks/tap/eksctl
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Eksctl already installed, ensuring latest version"
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing eksctl on linux"
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing eksctl on darwin"
    brew upgrade weaveworks/tap/eksctl
  fi
fi

# kustomize
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for kustomize"
if ! command -v kustomize &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing kustomize on linux"
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && \
      sudo mv ./kustomize /usr/local/bin
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing kustomize on darwin"
    brew install kustomize
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Kustomize already installed, ensuring latest version"
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Upgrading kustomize on linux"
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && \
      sudo mv ./kustomize /usr/local/bin
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Upgrading kustomize on darwin"
    brew upgrade kustomize
  fi
fi

# helm
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for helm"
if ! command -v helm &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing helm on linux"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
      chmod 700 get_helm.sh && \
      ./get_helm.sh
      rm -f ./get_helm.sh
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing helm on darwin"
    brew install helm
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Helm already installed, ensuring latest version"
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Upgrading helm on linux"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
      chmod 700 get_helm.sh && \
      ./get_helm.sh
      rm -f ./get_helm.sh
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Upgrading helm on darwin"
    brew upgrade helm
  fi
fi

# kind
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for kind"
if ! command -v kind &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing kind on linux"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64 && \
      chmod +x ./kind && \
      sudo mv kind /usr/local/bin/
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing kind on darwin"
    brew install kind
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Kind already installed"
fi

# kubebox
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for kubebox"
if ! command -v kubebox &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing kubebox on linux"
    curl -Lo kubebox https://github.com/astefanutti/kubebox/releases/download/v0.9.0/kubebox-linux && \
      chmod +x kubebox && \
      sudo mv kubebox /usr/local/bin/kubebox
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing kubebox on darwin"
    curl -Lo kubebox https://github.com/astefanutti/kubebox/releases/download/v0.9.0/kubebox-macos && \
      chmod +x kubebox && \
      sudo mv kubebox /usr/local/bin/kubebox
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Kubebox already installed"
fi

# stern
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for stern"
if ! command -v stern &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing stern on linux"
    curl -Lo stern https://github.com/wercker/stern/releases/download/1.11.0/stern_linux_amd64 && \
      chmod +x stern && \
      sudo mv stern /usr/local/bin/stern
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing stern on darwin"
    curl -Lo stern https://github.com/wercker/stern/releases/download/1.11.0/stern_darwin_amd64 && \
      chmod +x stern && \
      sudo mv stern /usr/local/bin/stern
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Stern already installed"
fi

# krew
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for krew"
if ! command -v ~/.krew/bin/kubectl-krew &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing krew on linux"
    cd "$(mktemp -d)" &&
      OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
      ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
      KREW="krew-${OS}_${ARCH}" &&
      curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
      tar zxvf "${KREW}.tar.gz" &&
      ./"${KREW}" install krew
    rm -f "${KREW}.tar.gz" ./krew-*
    echo 'export PATH=~/.krew/bin:$PATH' >> ~/.bashrc
    export PATH=~/.krew/bin:$PATH
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing krew on darwin"
    brew install krew
    echo 'export PATH="${PATH}:${HOME}/.krew/bin"' >> ~/.zshrc
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Krew already installed"
fi

# syft
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for syft"
if ! command -v ~/.syft/bin/syft &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing syft on linux"
    mkdir -p ~/.syft/bin
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/.syft/bin
    echo 'export PATH=~/.syft/bin:$PATH' >> ~/.bashrc
    export PATH=~/.syft/bin:$PATH
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing syft on darwin"
    brew tap anchore/syft
    brew install syft
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Syft already installed"
fi

# grype
printf "${BLUE}${BOLD}%s${RESET}\n" "Checking for grype"
if ! command -v ~/.grype/bin/grype &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing grype on linux"
    mkdir -p ~/.grype/bin
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ~/.grype/bin
    echo 'export PATH=~/.grype/bin:$PATH' >> ~/.bashrc
    export PATH=~/.grype/bin:$PATH
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf "${RED}${BOLD}%s${RESET}\n" "Installing grype on darwin"
    brew tap anchore/grype
    brew install grype
  fi
else
  printf "${YELLOW}%s${RESET}\n" "Grype already installed"
fi

# linkerd
# if ! command -v linkerd &>/dev/null; then
#   if [ "${OS}" == 'Linux' ]; then
#     printf '%s\n' "Installing linkerd on linux"
#     curl -fsL https://run.linkerd.io/install | sh
#     echo "export PATH=$PATH:/home/markus/.linkerd2/bin" >> ~/.bashrc
#   fi
#   if [ "${OS}" == 'Darwin' ]; then
#     printf '%s\n' "Installing linkerd on darwin"
#     url -fsL https://run.linkerd.io/install | sh
#     echo "export PATH=$PATH:/home/markus/.linkerd2/bin" >> ~/.zshrc
#   fi
# else
#   printf '%s\n' "linkerd already installed"
# fi
