#!/bin/bash

set -e

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE}))
ENV_FILE=${SCRIPT_DIR}/.env

source ${SCRIPT_DIR}/funcs.sh
source ${SCRIPT_DIR}/config.sh

dependencies() {
    check_root
    check_rpm_ostree
    install_packages ${DEPENDENCIES[@]}
    install_script_wizard ${SCRIPT_DIR}
}

setup() {
    config
}

config_menu() {
    if [[ -z "$1" ]]; then
        wizard menu "Config" \
               "Setup = ${BASH_SOURCE} setup" \
               "Pair BTECH UV-PRO = ${SCRIPT_DIR}/bt_pair.exp" \
               "Enable rfcomm KISS service = ${BASH_SOURCE} configure_rfcomm_service" \
               "Check AX.25 connection = ip link show dev ax0 || true" \
               "Show config = (echo; set -x; cat $(realpath ${ENV_FILE})) " \
               "Done = exit 2"
    else
        "$@"
    fi
}

main() {
    dependencies
    if [[ -z "$1" ]]; then
        wizard menu "BBS Admin Menu" \
               "Config = ${BASH_SOURCE} config_menu" \
               "Done = exit 1"
    else
        "$@"
    fi
}

main "$@"
