#!/bin/bash

set -e

SCRIPT_DIR=$(dirname ${BASH_SOURCE})
ENV_FILE=${SCRIPT_DIR}/.env

source ${SCRIPT_DIR}/funcs.sh
source ${SCRIPT_DIR}/config.sh

dependencies() {
    check_os_is_debian
    check_not_root
    check_has_sudo
    install_packages ${DEPENDENCIES[@]}
    install_script_wizard ${SCRIPT_DIR}
    setup_pipewire
}

setup() {
    dependencies
    config
}

main() {
    if [[ -z "$1" ]]; then
        wizard menu "BBS Admin Menu" \
               "Setup = ${BASH_SOURCE} setup" \
               "Show config = (echo; set -x; cat $(realpath ${ENV_FILE})) " \
               "Exit = exit 1"
    else
        "$@"
    fi
}

main "$@"
