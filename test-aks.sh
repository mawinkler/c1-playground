#!/bin/bash

YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
RESET=$(tput sgr0)

printf "${BLUE}${BOLD}%s${RESET}\n" "#######################################"
printf "${BLUE}${BOLD}%s${RESET}\n" "# Test AKS Cluster"
printf "${BLUE}${BOLD}%s${RESET}\n" "#######################################"
printf "${BLUE}${BOLD}%s${RESET}\n" ""
tests/aks.sh

printf "${YELLOW}%s${RESET}\n" "Test Falco"
tests/falco.sh

printf "${YELLOW}%s${RESET}\n" "Test Falco Cleanup"
tests/falco-cleanup.sh

printf "${YELLOW}%s${RESET}\n" "Test Smart Check"
tests/smartcheck.sh

printf "${YELLOW}%s${RESET}\n" "Test Container Security"
tests/container-security.sh

printf "${YELLOW}%s${RESET}\n" "Test Container Security Cleanup"
tests/container-security-cleanup.sh

printf "${YELLOW}%s${RESET}\n" "Test Smart Check Cleanup"
tests/smartcheck-cleanup.sh

printf "${YELLOW}%s${RESET}\n" "Test AKS Cleanup"
tests/aks-cleanup.sh
