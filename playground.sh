#!/bin/bash

set -e

# Check for dialog
DIALOG_INSTALLED=$(apt -qq list dialog 2>/dev/null)
if [[ "$DIALOG_INSTALLED" == *"installed"* ]]; then
    echo "dialog installed"
else
    sudo apt install -y dialog
fi

# Source helpers
. ./playground-helpers.sh

DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=0
WIDTH=0

# Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

# Duplicate (make a backup copy of) file descriptor 1 
# on descriptor 3
exec 3>&1

display_result() {
    dialog --title "$1" \
        --no-collapse \
        --msgbox "$result" 0 0
}

function check_k8s() {
    if $(kubectl config current-context &>/dev/null); then
        CLUSTER=$(kubectl config current-context)
    else
        CLUSTER="No Cluster"
    fi
}

get_editor() {
    if command -v nano &>/dev/null; then
        EDITOR=nano
    elif command -v vim &>/dev/null; then
        EDITOR=vim
    elif command -v vi &>/dev/null; then
        EDITOR=vi
    else
        echo No editor found. Aborting.
    fi
    echo Editor: ${EDITOR}
}

#######################################
# Main Menu
# Globals:
#   SC_NAMESPACE
#######################################
function menu_main() {

    # exec 3>&1

    while true
    do
        items=( 0 "Deploy/Update Tools" \
                1 "Create Cluster..." \
                2 "Deploy..." \
                3 "Tear Down Cluster" \
                4 "Current Deployments" \
                5 "Display Disk Space" \
                6 "Edit Configuration" )
            TITLE="Main Menu"
            check_k8s
            BACKTITLE="Playground: ${CLUSTER}"
        choice=$(dialog --title "${TITLE}" \
                    --backtitle "${BACKTITLE}" \
                    --cancel-label "Exit" \
                    --separate-widget "Widget" \
                    --menu "Please select" ${HEIGHT} ${WIDTH} 7 "${items[@]}" \
                    2>&1 1>&3)
        exit_status=$?
        case $exit_status in
            $DIALOG_CANCEL)
            clear
            echo "Program terminated."
            exec 3>&-
            exit
            ;;
            $DIALOG_ESC)
            clear
            echo "Program aborted." >&2
            exec 3>&-
            exit 1
            ;;
        esac
        case $choice in
            0)
                ./tools.sh
                ;;
            1)
                menu_create_cluster
                ;;
            2)
                menu_deploy
                ;;
            3)
                if [ -f ".teardown.sh" ]; then
                    ./.teardown.sh
                fi
                ;;
            4)
                if $(kubectl config current-context &>/dev/null); then
                    result=$(kubectl get deployments -A)
                    display_result "Deployments"
                fi
                ;;
            5)
                result=$(df -h)
                display_result "Disk Space"
                ;;
            6)
                ${EDITOR} config.json
                ;;
            *) ;; # some action on other
        esac
    done
}

function menu_create_cluster() {

    # exec 3>&1
    items=(1 "Local Cluster" \
           2 "Elastic Kubernetes Cluster" \
           3 "Azure Kubernetes Cluster" \
           4 "Google Kubernetes Engine")
    TITLE="Create a Cluster"
    check_k8s
    BACKTITLE="Playground: ${CLUSTER}"
    while choice=$(dialog --title "${TITLE}" \
                    --backtitle "${BACKTITLE}" \
                    --cancel-label "Back" \
                    --separate-widget "Widget" \
                    --menu "Please select" ${HEIGHT} ${WIDTH} 4 "${items[@]}" \
                    2>&1 1>&3)
    do
        exit_status=$?
        case $exit_status in
            $DIALOG_CANCEL)
            clear
            echo "Going back."
            break
            ;;
            $DIALOG_ESC)
            clear
            echo "Program aborted." >&2
            exec 3>&-
            exit 1
            ;;
        esac
        case $choice in
            1)
                clear
                ./up.sh
                echo "./down.sh" > ./.teardown.sh && chmod +x .teardown.sh
                ;;
            2) 
                clear
                clusters/rapid-eks.sh
                echo "./rapid-eks-down.sh" > ./.teardown.sh && chmod +x .teardown.sh
                ;;
            3)
                clear
                clusters/rapid-aks.sh
                echo "./rapid-aks-down.sh" > ./.teardown.sh && chmod +x .teardown.sh
                ;;
            4)
                clear
                clusters/rapid-gke.sh
                echo "./rapid-gke-down.sh" > ./.teardown.sh && chmod +x .teardown.sh
                ;;
            *) 
                ;;
        esac
    done
}

function menu_deploy() {

    # exec 3>&1
    items=(1 "Container Security" \
           2 "Smart Check" \
           3 "Falco" \
           4 "Gatekeeper"
           5 "Open Policy Agent"
           6 "Prometheus & Grafana"
           7 "Starboard")
    TITLE="Deploy"
    check_k8s
    BACKTITLE="Playground: ${CLUSTER}"
    while choice=$(dialog --title "${TITLE}" \
                    --backtitle "${BACKTITLE}" \
                    --cancel-label "Back" \
                    --separate-widget "Widget" \
                    --menu "Please select" ${HEIGHT} ${WIDTH} 7 "${items[@]}" \
                    2>&1 1>&3)
    do
        exit_status=$?
        case $exit_status in
            $DIALOG_CANCEL)
            clear
            echo "Going back."
            break
            ;;
            $DIALOG_ESC)
            clear
            echo "Program aborted." >&2
            exec 3>&-
            exit 1
            ;;
        esac
        case $choice in
            1)
                clear
                ./deploy-container-security.sh
                ;;
            2) 
                clear
                ./deploy-smartcheck.sh
                ;;
            3)
                clear
                ./deploy-falco.sh
                ;;
            4)
                clear
                ./deploy-gatekeeper.sh
                ;;
            5)
                clear
                ./deploy-opa.sh
                ;;
            6)
                clear
                ./deploy-prometheus-grafana.sh
                ;;
            7)
                clear
                ./deploy-starboard.sh
                ;;
            *) 
                ;;
        esac
    done
}

get_editor
while true
do
    menu_main
done

clear

# Close file descriptor 3
exec 3>&-
