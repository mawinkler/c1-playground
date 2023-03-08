# Atomic-Red-Script Test Dockerfile

# Pull base image. Due to Powershell dependency requirements, use 20.04 (focal) instead of the latest version.
FROM ubuntu:focal

# Basics
RUN \
  apt update && \
  apt install -y gnupg ca-certificates apt-transport-https software-properties-common wget

# Install test dependancies
RUN \
  apt install -y at ccrypt clang cron curl ed g++ gcc golang iproute2 iputils-ping kmod libpam0g-dev less lsof make netcat net-tools nmap p7zip python2 rsync samba selinux-utils ssh sshpass sudo tcpdump telnet tor ufw vim whois zip

# Install Powershell
RUN \
  # Download the Microsoft repository GPG keys
  wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb && \
  # Register the Microsoft repository GPG keys
  dpkg -i packages-microsoft-prod.deb && \
  # Update the list of packages after we added packages.microsoft.com
  apt update  && \
  # Install PowerShell Debian package
  apt install -y powershell 

# Install Atomic Red Team from pwsh
RUN \
  cd /root && pwsh -Command "IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing); Install-AtomicRedTeam -getAtomics"

# Copy test overrides/fixes
COPY atomics-overrides/ /root/AtomicRedTeam/atomics/

# Copy optional Job script
COPY RunTests.ps1 /root

# Define working directory.
WORKDIR /root

# Define default command.
CMD [sleep 99999]
