#!/bin/bash

set -e

SCRIPT_DIR=$(dirname ${BASH_SOURCE})
DEPENDENCIES=(
    ax25-apps ax25-tools direwolf pipewire pipewire-audio-client-libraries
    pulseaudio-utils wireplumber jq git curl
)

source ${SCRIPT_DIR}/funcs.sh

setup() {
    if [ ! -f /etc/debian_version ]; then
        fault "This script only supports Debian-based systems."
    else
        echo "## Debian $(cat /etc/debian_version) or similar OS detected."
    fi

    install_packages ${DEPENDENCIES[@]}
    install_script_wizard ${SCRIPT_DIR}

    ## CALLSIGN
    ask_valid CALLSIGN "Enter your callsign:" upcase validate_callsign
    save CALLSIGN
}

setup
