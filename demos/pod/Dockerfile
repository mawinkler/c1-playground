FROM ubuntu:20.04

# ##############################################################
# Configure run User
# ##############################################################
COPY ["templates/.bash_aliases", \
      "templates/.bashrc", \
      "/root/"]

RUN chown root.root \
          /root/.bash_aliases \
          /root/.bashrc

# COPY templates/add-apt-repository /usr/local/bin

# ##############################################################
# Add required Repos
# ##############################################################
RUN \
    apt update && \
    \
    # Install packages
    export DEBIAN_FRONTEND=noninteractive && \
    apt install -y \
        apache2-utils \
        apt-transport-https \
        apt-utils \
        bash-completion \
        # ca-certificates \
        curl \
        dnsutils \
        git \
        gnupg \
        gnupg2 \
        # groff \
        iputils-ping \
        jq \
        less \
        # libffi6 \
        # libffi-dev \
        # libssl-dev \
        # locales-all \
        # lsb-release \
        lvm2 \
        nano \
        net-tools \
        pv \
        # python3 \
        # python3-pip \
        screen \
        # software-properties-common \
        # sudo \
        vim \
        wget \
        zip
    #     zip && \
    # \
    # Enable Universe Repo
# RUN add-apt-repository universe 
#     \

# use
# RUN \
#     # Add Google Repo
#     curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
#     echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
#     \
#     # Add Helm Repo
#     curl https://baltocdn.com/helm/signing.asc | \
#         apt-key add - && \
#     apt-get install apt-transport-https --yes && \
#     echo "deb https://baltocdn.com/helm/stable/debian/ all main" | \
#         tee /etc/apt/sources.list.d/helm-stable-debian.list

# use
# RUN \
#     apt update && \
#     \
#     # AWS
#     # curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip && \
#     # unzip awscliv2.zip && \
#     # aws/install && \
#     # rm -rf awscliv2.zip \
#     #     aws \
#     #     /usr/local/aws-cli/v2/*/dist/aws_completer \
#     #     /usr/local/aws-cli/v2/*/dist/awscli/data/ac.index \
#     #     /usr/local/aws-cli/v2/*/dist/awscli/examples && \
#     # \
#     # Kubectl
#     apt install -y kubectl && \
#     \
#     # Helm
#     apt install -y helm && \
#     \
#     # Docker
#     apt install -y docker.io && \
#     \
#     # Stern
#     curl --silent \
#         --location https://github.com/wercker/stern/releases/download/1.11.0/stern_linux_amd64 -o stern && \
#     chmod +x stern && \
#     mv stern /usr/local/bin/stern && \
#     \
#     # Cleanup
#     rm -rf /var/lib/apt/list/*

COPY godmode /usr/local/bin
COPY demo-magic.sh /root/demo/
COPY demo-c1cs-rt.sh /root/demo/

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
