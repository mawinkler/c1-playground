#!/bin/bash

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
BOLD=$(tput bold)
RESET=$(tput sgr0)

printf "${BLUE}${BOLD}%s${RESET}\n" "#######################################"
printf "${BLUE}${BOLD}%s${RESET}\n" "# Test Kind Cluster"
printf "${BLUE}${BOLD}%s${RESET}\n" "#######################################"
printf "${BLUE}${BOLD}%s${RESET}\n" ""
tests/kind.sh

printf "${YELLOW}%s${RESET}\n" "Test Registry"
tests/registry.sh

printf "${YELLOW}%s${RESET}\n" "Test Falco"
tests/falco.sh

printf "${YELLOW}%s${RESET}\n" "Test Falco Cleanup"
tests/falco-cleanup.sh

printf "${YELLOW}%s${RESET}\n" "Test Container Security"
tests/container-security.sh

printf "${YELLOW}%s${RESET}\n" "Test Container Security Cleanup"
tests/container-security-cleanup.sh

printf "${YELLOW}%s${RESET}\n" "Test Registry Cleanup"
tests/registry-cleanup.sh

printf "${YELLOW}%s${RESET}\n" "Test Kind Cleanup"
tests/kind-cleanup.sh
