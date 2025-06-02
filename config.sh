#!/bin/bash

set -e

DEPENDENCIES=(
    ax25-apps ax25-tools direwolf jq git curl
)

__configure_sound_device() {
    local varname="$1"
    local prompt="$2"
    check_var varname prompt
    mapfile -t full_devices < <(list_alsa_device_names)
    if [ "${#full_devices[@]}" -eq 0 ]; then
        fault "No audio devices found."
    fi
    local existing_device
    existing_device=$(get "$varname")
    local descriptions=()
    local dev_names=()
    local default_display=""
    for entry in "${full_devices[@]}"; do
        IFS='|' read -r dev desc <<< "$entry"
        dev_names+=("$dev")
        desc="${desc#"${desc%%[![:space:]]*}"}"  # trim leading space
        descriptions+=("$desc")

        # If this dev matches the saved name, remember the description
        if [[ "$dev" == "$existing_device" ]]; then
            default_display="$desc"
        fi
    done
    local index
    index=$(wizard choose -n "$prompt" "${descriptions[@]}" --default "$default_display")
    local selected="${dev_names[$index]}"
    printf -v "$varname" '%s' "$selected"
    save "$varname"
}

configure_sound_device() {
    __configure_sound_device SOUND_DEVICE "Select your sound device"
}

configure_volume_input_device() {
    set_default SOUND_VOLUME_INPUT 0
    ask_valid SOUND_VOLUME_INPUT "Enter the INPUT volume GAIN (decimal between 0 and 1)" validate_decimal
    save SOUND_VOLUME_INPUT
}

configure_volume_output_device() {
    set_default SOUND_VOLUME_OUTPUT 0.25
    ask_valid SOUND_VOLUME_OUTPUT "Enter the OUTPUT volume (decimal between 0 and 1)" validate_decimal
    save SOUND_VOLUME_OUTPUT
}

configure_ptt_rts() {
    if wizard confirm "Do you want to trigger the radio PTT via USB serial RTS (digirig)?" yes; then
        mapfile -t devices < <(compgen -G "/dev/ttyUSB*" || true)
        if [[ "${#devices[@]}" -eq 0 ]]; then
            fault "No /dev/ttyUSB* devices found."
        fi
        local existing_device=$(get PTT_RTS_DEVICE)
        PTT_RTS_DEVICE="$(wizard choose "Select your USB serial device for PTT RTS" "${devices[@]}" --default "$existing_device")"
    else
        PTT_RTS_DEVICE=""
    fi
    save PTT_RTS_DEVICE
}

configure_callsign() {
    ask_valid CALLSIGN "Enter your callsign:" upcase validate_callsign
    save CALLSIGN
}

config() {
    configure_callsign
    echo
    configure_sound_device
    echo
    configure_volume_input_device
    echo
    configure_volume_output_device
    echo
    configure_ptt_rts
    echo
    echo "########################################"
    echo "## Configuration complete."
    echo "########################################"
    echo
}
