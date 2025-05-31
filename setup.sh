#!/bin/bash

set -e

BBS_DIR=$(dirname ${BASH_SOURCE})

stderr(){ echo "$@" >/dev/stderr; }
error(){ stderr "Error: $@"; }
cancel(){ stderr "Canceled."; exit 2; }
fault(){ test -n "$1" && error $1; stderr "Exiting."; exit 1; }
check_var(){
    local __missing=false
    local __vars="$@"
    for __var in ${__vars}; do
        if [[ -z "${!__var}" ]]; then
            error "${__var} variable is missing."
            __missing=true
        fi
    done
    if [[ ${__missing} == true ]]; then
        fault
    fi
}

install_script_wizard() {
    local REPO=https://github.com/EnigmaCurry/script-wizard
    local INSTALLER=https://raw.githubusercontent.com/EnigmaCurry/script-wizard/refs/heads/master/install.sh
    local DEST=${1}
    check_var DEST
    if [[ ! -f ${DEST}/script-wizard ]]; then
        echo "This tool requires script-wizard from ${REPO}"
        read -e -p "Install script-wizard automatically? [y/N]: " answer
        if [[ ${answer,,} != "y" ]]; then
            echo "Canceled"
            exit 1
        fi
        bash <(curl ${INSTALLER}) "${DEST}"
    fi
}

install_script_wizard ${BBS_DIR}
