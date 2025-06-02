#!/bin/bash

set -e

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE}))
ENV_FILE=${SCRIPT_DIR}/.env

source ${SCRIPT_DIR}/funcs.sh
source ${SCRIPT_DIR}/config.sh

dependencies() {
    check_os_is_debian
    check_not_root
    check_has_sudo
    install_packages ${DEPENDENCIES[@]}
    install_script_wizard ${SCRIPT_DIR}
}

setup() {
    dependencies
    config
}

direwolf_menu() {
    if [[ -z "$1" ]]; then
        wizard menu "Dire Wolf" \
               "Status (press Q to quit) = systemctl status --user direwolf || true" \
               "Logs (press Ctrl-C to quit) =  journalctl -f _SYSTEMD_USER_UNIT=direwolf.service || true" \
               "Enable (restart) Dire Wolf service = ${BASH_SOURCE} enable_direwolf_service" \
               "Disable Dire Wolf service = ${BASH_SOURCE} disable_direwolf_service" \
               "Done = exit 2"
    else
        "$@"
    fi
}

main() {
    if [[ -z "$1" ]]; then
        wizard menu "BBS Admin Menu" \
               "Config = ${BASH_SOURCE} setup" \
               "Show config = (echo; set -x; cat $(realpath ${ENV_FILE})) " \
               "Dire Wolf = ${BASH_SOURCE} direwolf_menu" \
               "Done = exit 1"
    else
        "$@"
    fi
}

main "$@"
